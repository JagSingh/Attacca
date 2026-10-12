//
//  Views.swift
//  Attacca
//
//  (c) 2026 jag.m.singh@gmail.com
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Root

struct RootView: View {
    @Environment(FolderAccess.self) private var access
    @Environment(Player.self) private var player
    @State private var isPicking = false

    var body: some View {
        NavigationStack {
            Group {
                if let root = access.rootURL {
                    FolderView(url: root, title: root.lastPathComponent)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button { isPicking = true } label: {
                                    Image(systemName: "folder.badge.gearshape")
                                }
                                .accessibilityLabel("Change music folder")
                            }
                        }
                } else {
                    ContentUnavailableView {
                        Label("No Music Folder", systemImage: "folder")
                    } description: {
                        Text("Choose a folder in iCloud Drive that contains your music.")
                    } actions: {
                        Button("Choose Folder") { isPicking = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationDestination(for: FolderItem.self) { folder in
                FolderView(url: folder.url, title: folder.name)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if player.current != nil { MiniPlayer() }
        }
        .fileImporter(isPresented: $isPicking, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { access.set(url) }
        }
        .alert("Playback",
               isPresented: Binding(get: { player.errorMessage != nil },
                                    set: { if !$0 { player.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(player.errorMessage ?? "")
        }
    }
}

// MARK: - Folder

struct FolderView: View {
    let url: URL
    let title: String

    @Environment(Player.self) private var player
    @State private var contents = FolderContents()
    @State private var loadError: String?

    var body: some View {
        List {
            if !contents.folders.isEmpty {
                Section("Folders") {
                    ForEach(contents.folders) { folder in
                        NavigationLink(value: folder) {
                            Label(folder.name, systemImage: "folder")
                        }
                    }
                }
            }

            if !contents.tracks.isEmpty {
                Section {
                    ForEach(Array(contents.tracks.enumerated()), id: \.element.id) { i, track in
                        Button {
                            player.play(contents.tracks, startAt: i)
                        } label: {
                            TrackRow(track: track, isCurrent: player.current?.id == track.id)
                        }
                        .foregroundStyle(.primary)
                    }
                } header: {
                    HStack {
                        Text("\(contents.tracks.count) tracks")
                        Spacer()
                        Button("Play All") { player.play(contents.tracks) }
                            .font(.subheadline.weight(.semibold))
                            .textCase(nil)
                    }
                }
            }
        }
        .overlay {
            if let loadError {
                ContentUnavailableView("Can’t Open Folder",
                                       systemImage: "exclamationmark.triangle",
                                       description: Text(loadError))
            } else if contents.isEmpty {
                ContentUnavailableView("Empty Folder",
                                       systemImage: "music.note",
                                       description: Text("No subfolders or audio files here."))
            }
        }
        .navigationTitle(title)
        .toolbar {
            if contents.tracks.contains(where: { !$0.isLocal }) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        contents.tracks.forEach { if !$0.isLocal { CloudFile.startDownload($0.url) } }
                    } label: {
                        Image(systemName: "icloud.and.arrow.down")
                    }
                    .accessibilityLabel("Download all tracks")
                }
            }
        }
        .task(id: url) { reload() }
        .refreshable { reload() }
    }

    private func reload() {
        do {
            contents = try Library.contents(of: url)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

struct TrackRow: View {
    let track: Track
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCurrent ? "speaker.wave.2.fill" : "music.note")
                .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
                .frame(width: 22)
            Text(track.title)
                .lineLimit(1)
                .fontWeight(isCurrent ? .semibold : .regular)
            Spacer()
            if !track.isLocal {
                Image(systemName: "icloud")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Not downloaded")
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Mini player

struct MiniPlayer: View {
    @Environment(Player.self) private var player

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text(player.current?.title ?? "")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(player.index + 1) of \(player.queue.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if player.isLoading { ProgressView() }
            Button { player.previous() } label: { Image(systemName: "backward.fill") }
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 28)
            }
            Button { player.next() } label: { Image(systemName: "forward.fill") }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
