import Foundation

/// Atomic, versioned, on-device files. History keeps metadata only, not all terrain in memory.
actor ScanArchive {
    private let directory: URL

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "SavedScans", directoryHint: .isDirectory)) {
        self.directory = directory
    }

    func save(_ scan: SavedScan) throws {
        try scan.validate()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(scan)
        try data.write(to: url(for: scan.id), options: .atomic)
    }

    func load(_ id: UUID) throws -> SavedScan {
        let scan = try JSONDecoder().decode(SavedScan.self, from: Data(contentsOf: url(for: id)))
        try scan.validate()
        guard scan.id == id else { throw ScanArchiveError.invalidScan }
        return scan
    }

    func history() throws -> ScanHistory {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return ScanHistory(scans: [], unreadableCount: 0)
        }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        var summaries: [ScanSummary] = []
        var unreadable = 0
        for file in files where file.pathExtension == "json" {
            do {
                guard let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent) else {
                    throw ScanArchiveError.invalidScan
                }
                summaries.append(try load(id).summary)
            } catch { unreadable += 1 }
        }
        return ScanHistory(scans: summaries.sorted { $0.date > $1.date }, unreadableCount: unreadable)
    }

    private func url(for id: UUID) -> URL { directory.appending(path: id.uuidString + ".json") }
}
