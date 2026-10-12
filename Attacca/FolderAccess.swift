//
//  FolderAccess.swift
//  Attacca
//
//  (c) 2026 jag.m.singh@gmail.com
//

import Foundation
import Observation

/// Holds security-scoped access to the user-granted root folder (ideally iCloud Drive itself),
/// plus the in-app navigation path below it. Both persist across launches, so the app reopens
/// in the last folder viewed.
@MainActor
@Observable
final class FolderAccess {
    private(set) var rootURL: URL?

    /// Folders opened below the root, in order. Drives the NavigationStack and the breadcrumb.
    var path: [FolderItem] = []

    @ObservationIgnored private let bookmarkKey = "rootFolderBookmark"
    @ObservationIgnored private let pathKey = "lastFolderPath"

    init() {
        restore()
    }

    /// True when the URL is the top level of iCloud Drive (not a folder inside it).
    nonisolated static func isICloudDriveRoot(_ url: URL) -> Bool {
        url.lastPathComponent == "com~apple~CloudDocs"
            || FileManager.default.displayName(atPath: url.path) == "iCloud Drive"
    }

    /// Display name for the root crumb: "iCloud Drive" when the whole drive was granted.
    var rootName: String {
        guard let rootURL else { return "" }
        if Self.isICloudDriveRoot(rootURL) { return "iCloud Drive" }
        return FileManager.default.displayName(atPath: rootURL.path)
    }

    /// True when only a sub-folder (not all of iCloud Drive) has been granted.
    var isLimitedToSubfolder: Bool {
        guard let rootURL else { return false }
        return !Self.isICloudDriveRoot(rootURL)
    }

    /// Called with the URL returned by `.fileImporter`.
    func set(_ url: URL) {
        stopAccess()
        guard url.startAccessingSecurityScopedResource() else { return }
        saveBookmark(for: url)
        rootURL = url
        path = []
        savePath()
    }

    /// Jump to a breadcrumb level: 0 = root, n = the n-th folder in `path`.
    func goTo(level: Int) {
        guard level >= 0, level < path.count else { return }
        path = Array(path.prefix(level))
    }

    /// Persist the current path as folder names relative to the root.
    func savePath() {
        UserDefaults.standard.set(path.map(\.name), forKey: pathKey)
    }

    func clear() {
        stopAccess()
        path = []
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: pathKey)
    }

    // MARK: - Private

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data,
                                 options: [],
                                 relativeTo: nil,
                                 bookmarkDataIsStale: &isStale),
              url.startAccessingSecurityScopedResource()
        else { return }
        if isStale { saveBookmark(for: url) }
        rootURL = url
        restorePath(under: url)
    }

    /// Rebuild the saved path, stopping at the first folder that no longer exists.
    private func restorePath(under root: URL) {
        guard let names = UserDefaults.standard.stringArray(forKey: pathKey) else { return }
        var items: [FolderItem] = []
        var current = root
        for name in names {
            let next = current.appendingPathComponent(name, isDirectory: true)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: next.path, isDirectory: &isDir),
                  isDir.boolValue else { break }
            items.append(FolderItem(url: next, name: name))
            current = next
        }
        path = items
    }

    private func saveBookmark(for url: URL) {
        if let data = try? url.bookmarkData(options: [],
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        }
    }

    private func stopAccess() {
        rootURL?.stopAccessingSecurityScopedResource()
        rootURL = nil
    }
}
