//
//  CloudFile.swift
//  Attacca
//
//  (c) 2026 jag.m.singh@gmail.com
//

import Foundation

enum CloudFileError: LocalizedError {
    case timedOut
    var errorDescription: String? {
        "Download timed out. Check your connection, or mark the folder “Keep Downloaded” in the Files app."
    }
}

/// Makes sure an iCloud Drive (or other File Provider) file is on the device before playback.
enum CloudFile {
    /// True when the file's bytes are on the device.
    /// Uses iCloud's download status when iOS reports it; otherwise detects a "dataless"
    /// placeholder (has a size, but no disk space allocated).
    static func isDownloaded(_ url: URL) -> Bool {
        let keys: Set<URLResourceKey> = [.ubiquitousItemDownloadingStatusKey,
                                         .fileSizeKey, .totalFileAllocatedSizeKey]
        guard let v = try? url.resourceValues(forKeys: keys)
        else { return FileManager.default.fileExists(atPath: url.path) }
        if let status = v.ubiquitousItemDownloadingStatus {
            return status == .current || status == .downloaded
        }
        if let size = v.fileSize, size > 0, let allocated = v.totalFileAllocatedSize, allocated == 0 {
            return false
        }
        return true
    }

    /// Kicks off a non-blocking download (used for prefetch and "Download All").
    static func startDownload(_ url: URL) {
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
    }

    /// Waits until the file is local. Cancellable; times out instead of hanging offline.
    static func ensureLocal(_ url: URL, timeout: Duration = .seconds(90)) async throws {
        let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey])

        // Not iCloud (e.g. another provider such as Dropbox via Files): a coordinated
        // read asks the provider to materialize the file.
        if let values, values.isUbiquitousItem != true {
            try await coordinatedRead(url)
            return
        }

        if isDownloaded(url) { return }
        try FileManager.default.startDownloadingUbiquitousItem(at: url)

        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            try await Task.sleep(for: .milliseconds(400))
            var fresh = url
            fresh.removeAllCachedResourceValues()
            let status = try? fresh.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey,
                                                             .ubiquitousItemDownloadingErrorKey])
            if let error = status?.ubiquitousItemDownloadingError { throw error }
            if status?.ubiquitousItemDownloadingStatus == .current ||
               status?.ubiquitousItemDownloadingStatus == .downloaded { return }
        }
        throw CloudFileError.timedOut
    }

    private static func coordinatedRead(_ url: URL) async throws {
        try await Task.detached(priority: .userInitiated) {
            var coordError: NSError?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { _ in }
            if let coordError { throw coordError }
        }.value
    }
}
