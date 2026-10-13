//
//  Views.swift
//  Attacca
//
//  (c) 2026 jag.m.singh@gmail.com
//

import SwiftUI

// MARK: - Root

struct RootView: View {
    @Environment(FolderAccess.self) private var access
    @Environment(Player.self) private var player
    @State private var isPicking = false        // first-run picker
    @State private var showSetup = false        // setup sheet from the folder button
    @State private var sheetPicking = false     // picker launched from that sheet

    var body: some View {
        @Bindable var access = access

        NavigationStack(path: $access.path) {
            Group {
                if let root = access.rootURL {
                    FolderView(url: root, level: 0)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button { showSetup = true } label: {
                                    Image(systemName: "gearshape")
                                }
                                .accessibilityLabel("Settings")
                            }
                        }
                } else {
                    SetupView(isFirstRun: true) { isPicking = true }
                }
            }
            .navigationDestination(for: FolderItem.self) { folder in
                FolderView(url: folder.url,
                           level: (access.path.firstIndex(of: folder) ?? access.path.count - 1) + 1)
            }
        }
        .onChange(of: access.path) { access.savePath() }
        .safeAreaInset(edge: .bottom) {
            if player.current != nil { MiniPlayer() }
        }
        .iCloudPicker(isPresented: $isPicking)
        .sheet(isPresented: $showSetup) {
            NavigationStack {
                SetupView(isFirstRun: false) { sheetPicking = true }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showSetup = false }
                        }
                    }
            }
            .iCloudPicker(isPresented: $sheetPicking) { showSetup = false }
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

// MARK: - Breadcrumb

/// "iCloud Drive : Chopin : Nocturnes" — every ancestor is tappable.
/// Long names truncate in the middle; the current folder keeps priority.
struct Breadcrumb: View {
    let level: Int
    @Environment(FolderAccess.self) private var access

    private var crumbs: [String] {
        [access.rootName] + access.path.prefix(level).map(\.name)
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(crumbs.enumerated()), id: \.offset) { i, name in
                if i > 0 {
                    Text(":").foregroundStyle(.tertiary)
                }
                if i == crumbs.count - 1 {
                    Text(name)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .layoutPriority(1)
                } else {
                    Button { access.goTo(level: i) } label: {
                        Text(name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }
            Spacer(minLength: 0)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

// MARK: - Folder

struct FolderView: View {
    let url: URL
    let level: Int          // 0 = root; matches the breadcrumb depth

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
        .safeAreaInset(edge: .top, spacing: 0) { Breadcrumb(level: level) }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
        .onChange(of: player.current?.id) { reload() }
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
        VStack(alignment: .leading, spacing: 10) {
            // Full file name (no path), wrapped over as many lines as it needs.
            Text(player.current?.name ?? "")
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 22) {
                Text("\(player.index + 1) of \(player.queue.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}
