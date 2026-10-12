//
//  FolderAccess.swift
//  Attacca
//
//  (c) 2026 jag.m.singh@gmail.com
//

import Foundation
import Observation

/// Holds security-scoped access to the user-chosen root music folder
/// and persists it across launches as a bookmark.
@MainActor
@Observable
final class FolderAccess {
    private(set) var rootURL: URL?

    @ObservationIgnored private let bookmarkKey = "rootFolderBookmark"

    init() {
        restore()
    }

    /// Called with the URL returned by `.fileImporter`.
    func set(_ url: URL) {
        stopAccess()
        guard url.startAccessingSecurityScopedResource() else { return }
        save(bookmarkFor: url)
        rootURL = url
    }

    func clear() {
        stopAccess()
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
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
        if isStale { save(bookmarkFor: url) }
        rootURL = url
    }

    private func save(bookmarkFor url: URL) {
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
