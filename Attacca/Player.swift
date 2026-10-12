//
//  Player.swift
//  Attacca
//
//  (c) 2026 jag.m.singh@gmail.com
//

import AVFoundation
import MediaPlayer
import Observation
import SFBAudioEngine

/// Plays a folder's tracks in order with gapless transitions.
///
/// Built on SFBAudioEngine's `AudioPlayer` (AVAudioEngine-based), which decodes
/// Opus, Ogg Vorbis, FLAC, WavPack, Monkey's Audio, Musepack and more, in addition
/// to everything Core Audio handles (MP3, AAC/M4A, ALAC, WAV, AIFF, CAF).
///
/// Gapless flow: track N is started with `play(_:)`; as soon as track N+1 is on the
/// device it is `enqueue(_:)`d, so the engine flows straight into it.
/// `nowPlayingChanged` tells us when the engine has moved on.
@MainActor
@Observable
final class Player {
    private(set) var queue: [Track] = []
    private(set) var index = 0
    private(set) var isPlaying = false
    private(set) var isLoading = false
    var errorMessage: String?

    var current: Track? { queue.indices.contains(index) ? queue[index] : nil }

    @ObservationIgnored private let engine = AudioPlayer()
    @ObservationIgnored private let delegateBridge = DelegateBridge()
    @ObservationIgnored private var startTask: Task<Void, Never>?
    @ObservationIgnored private var enqueueTask: Task<Void, Never>?
    @ObservationIgnored private var enqueuedIndex: Int?     // track handed to the engine, not yet playing
    @ObservationIgnored private var fetchingIndex: Int?     // next track still downloading
    @ObservationIgnored private var isStarting = false      // between start(_:) and the engine confirming it
    @ObservationIgnored private var duration: Double?

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        delegateBridge.owner = self
        engine.delegate = delegateBridge
        setupRemoteCommands()
    }

    // MARK: - Public controls

    func play(_ tracks: [Track], startAt i: Int = 0) {
        queue = tracks
        start(i)
    }

    func togglePlayPause() {
        if engine.isStopped {
            if current != nil { start(index) }
            return
        }
        try? engine.togglePlayPause()
    }

    func resume() {
        if engine.isStopped { togglePlayPause() } else { _ = engine.resume() }
    }

    func pause() {
        _ = engine.pause()
    }

    func next() {
        if index + 1 < queue.count { start(index + 1) } else { finish() }
    }

    func previous() {
        if (engine.currentTime ?? 0) > 3 || index == 0 {
            seek(to: 0)
        } else {
            start(index - 1)
        }
    }

    func seek(to seconds: Double) {
        guard engine.supportsSeeking else { return }
        _ = engine.seek(time: seconds)
        updateNowPlaying()
    }

    // MARK: - Starting a track (user action or recovery)

    private func start(_ i: Int) {
        guard queue.indices.contains(i) else { finish(); return }
        startTask?.cancel()
        enqueueTask?.cancel()
        enqueuedIndex = nil
        fetchingIndex = nil
        engine.stop()
        index = i
        duration = nil
        isLoading = true
        isStarting = true
        let track = queue[i]

        startTask = Task { [weak self] in
            do {
                try await CloudFile.ensureLocal(track.url)
                guard let self, !Task.isCancelled else { return }
                try? AVAudioSession.sharedInstance().setActive(true)
                try self.engine.play(track.url)   // clears any engine queue, starts immediately
                // nowPlayingChanged → didStartPlaying(url:) finishes the bookkeeping.
            } catch {
                guard let self, !Task.isCancelled, !(error is CancellationError) else { return }
                self.skip(i, track: track, error: error)
            }
        }
    }

    private func skip(_ i: Int, track: Track, error: Error) {
        isStarting = false
        errorMessage = "Skipped “\(track.title)”: \(error.localizedDescription)"
        if i + 1 < queue.count { start(i + 1) } else { finish() }
    }

    /// Download track j (if needed) and hand it to the engine for gapless playback.
    private func scheduleNext(after i: Int) {
        enqueueTask?.cancel()
        let j = i + 1
        guard queue.indices.contains(j) else { return }
        let track = queue[j]
        fetchingIndex = j

        enqueueTask = Task { [weak self] in
            do {
                try await CloudFile.ensureLocal(track.url)
                guard let self, !Task.isCancelled else { return }
                self.fetchingIndex = nil
                if self.engine.isStopped {
                    // Current track ended before the next one finished downloading.
                    self.start(j)
                } else {
                    try self.engine.enqueue(track.url)
                    self.enqueuedIndex = j
                    // Pre-fetch one more so a slow network doesn't break the chain later.
                    if self.queue.indices.contains(j + 1), !self.queue[j + 1].isLocal {
                        CloudFile.startDownload(self.queue[j + 1].url)
                    }
                }
            } catch {
                guard let self, !Task.isCancelled, !(error is CancellationError) else { return }
                self.fetchingIndex = nil
                self.errorMessage = "Skipped “\(track.title)”: \(error.localizedDescription)"
                if self.engine.isStopped, self.queue.indices.contains(j + 1) {
                    self.start(j + 1)
                } else if self.engine.isStopped {
                    self.finish()
                } else {
                    self.scheduleNext(after: j)   // try the one after
                }
            }
        }
    }

    private func finish() {
        startTask?.cancel()
        enqueueTask?.cancel()
        enqueuedIndex = nil
        fetchingIndex = nil
        isStarting = false
        engine.stop()
        isPlaying = false
        isLoading = false
        updateNowPlaying()
    }

    private func markLocal(at i: Int) {
        guard queue.indices.contains(i) else { return }
        queue[i].isLocal = true
    }

    // MARK: - Engine events (delivered on the main actor by DelegateBridge)

    fileprivate func didStartPlaying(url: URL?) {
        guard let url else { return }
        let path = url.standardizedFileURL.path
        let match = queue.firstIndex { $0.url.standardizedFileURL.path == path }
        // While a user-initiated start is pending, ignore stale events from the previous track.
        if isStarting, let match, match != index { return }
        let i = match ?? enqueuedIndex ?? index

        isStarting = false
        index = i
        if enqueuedIndex == i { enqueuedIndex = nil }
        isLoading = false
        markLocal(at: i)
        duration = engine.totalTime
        updateNowPlaying()
        if duration == nil { refreshDurationSoon() }
        if enqueuedIndex == nil { scheduleNext(after: i) }
    }

    fileprivate func playbackStateChanged(_ state: AudioPlayer.PlaybackState) {
        isPlaying = (state == .playing)
        updateNowPlaying()
    }

    fileprivate func endOfAudio() {
        guard !isStarting else { return }   // engine.stop()/play() during a track change
        isPlaying = false
        // Next track still downloading: scheduleNext will start it when ready.
        if fetchingIndex != nil {
            isLoading = true
            updateNowPlaying()
            return
        }
        finish()
    }

    fileprivate func encountered(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    private func refreshDurationSoon() {
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, let total = self.engine.totalTime else { return }
            self.duration = total
            self.updateNowPlaying()
        }
    }

    // MARK: - Lock screen / Control Center

    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }; return .success
        }
        c.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }; return .success
        }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }; return .success
        }
        c.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }; return .success
        }
        c.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }; return .success
        }
        c.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let t = e.positionTime
            Task { @MainActor in self?.seek(to: t) }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let track = current, !engine.isStopped || isLoading else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyAlbumTitle: track.url.deletingLastPathComponent().lastPathComponent,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyPlaybackQueueIndex: index,
            MPNowPlayingInfoPropertyPlaybackQueueCount: queue.count,
        ]
        if let elapsed = engine.currentTime { info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed }
        if let duration { info[MPMediaItemPropertyPlaybackDuration] = duration }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

// MARK: - Delegate bridge

/// SFBAudioEngine calls its delegate on an unspecified queue; hop to the main actor.
/// (Audio-session interruptions are handled inside AudioPlayer itself.)
private final class DelegateBridge: NSObject, AudioPlayer.Delegate {
    weak var owner: Player?

    func audioPlayer(_ audioPlayer: AudioPlayer, nowPlayingChanged nowPlaying: PCMDecoding?) {
        let url = nowPlaying?.inputSource.url
        let owner = self.owner
        Task { @MainActor in owner?.didStartPlaying(url: url) }
    }

    func audioPlayer(_ audioPlayer: AudioPlayer, playbackStateChanged playbackState: AudioPlayer.PlaybackState) {
        let owner = self.owner
        Task { @MainActor in owner?.playbackStateChanged(playbackState) }
    }

    func audioPlayerEndOfAudio(_ audioPlayer: AudioPlayer) {
        let owner = self.owner
        Task { @MainActor in owner?.endOfAudio() }
    }

    func audioPlayer(_ audioPlayer: AudioPlayer, encounteredError error: Error) {
        let owner = self.owner
        Task { @MainActor in owner?.encountered(error) }
    }
}
