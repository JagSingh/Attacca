//
//  Library.swift
//  Attacca
//
//  (c) 2026 jag.m.singh@gmail.com
//

import Foundation
import SFBAudioEngine

struct FolderItem: Identifiable, Hashable {
    let url: URL
    let name: String
    var id: URL { url }
}

struct Track: Identifiable, Hashable {
    let url: URL
    let name: String          // file name incl. extension
    var isLocal: Bool         // false = iCloud placeholder, not yet downloaded
    var id: URL { url }
    var title: String { (name as NSString).deletingPathExtension }
}

struct FolderContents {
    var folders: [FolderItem] = []
    var tracks: [Track] = []
    var isEmpty: Bool { folders.isEmpty && tracks.isEmpty }
}

enum Library {
    /// Lists subfolders and audio files, each sorted by name.
    /// Sort uses Finder-style ordering ("Track 2" before "Track 10").
    static func contents(of folder: URL) throws -> FolderContents {
        let items = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [] // keep hidden files: legacy iCloud placeholders are ".name.icloud"
        )

        var result = FolderContents()
        for item in items {
            let name = displayName(for: item)
            if name.hasPrefix(".") { continue } // genuinely hidden file

            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                result.folders.append(FolderItem(url: item, name: name))
            } else if isAudio(name) {
                let realURL = folder.appendingPathComponent(name)
                result.tracks.append(Track(url: realURL, name: name, isLocal: CloudFile.isDownloaded(realURL)))
            }
        }

        result.folders.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        result.tracks.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return result
    }

    /// Maps legacy placeholder names ".Song.mp3.icloud" back to "Song.mp3".
    static func displayName(for url: URL) -> String {
        let name = url.lastPathComponent
        let suffix = ".icloud"
        if name.hasPrefix("."), name.hasSuffix(suffix), name.count > suffix.count + 1 {
            return String(name.dropFirst().dropLast(suffix.count))
        }
        return name
    }

    /// Every extension SFBAudioEngine can decode (opus, ogg, flac, mp3, m4a, wav, aiff, wv, ape, ...).
    /// Listing only these guarantees every listed file is playable.
    static let decodableExtensions: Set<String> = Set(AudioDecoder.supportedPathExtensions.map { $0.lowercased() })

    static func isAudio(_ fileName: String) -> Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return !ext.isEmpty && decodableExtensions.contains(ext)
    }
}
