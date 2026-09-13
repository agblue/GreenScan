import Foundation

/// The measured height field is saved, not just the currently visible display layers.
struct SavedScan: Codable, Sendable, Identifiable {
    let version: Int
    let id: UUID
    let date: Date
    let isDemo: Bool
    let snapshot: TerrainSnapshot

    init(snapshot: TerrainSnapshot, isDemo: Bool, date: Date = .now) {
        version = 1
        id = UUID()
        self.date = date
        self.isDemo = isDemo
        self.snapshot = snapshot
    }

    var summary: ScanSummary {
        ScanSummary(id: id, date: date, isDemo: isDemo, area: snapshot.area, pointCount: snapshot.heights.count)
    }

    func validate() throws {
        guard version == 1, snapshot.reference.isFinite,
              !snapshot.heights.isEmpty, snapshot.heights.count <= TerrainMap.maximumCells,
              snapshot.heights.allSatisfy({ key, height in
                  (-1_000...1_000).contains(key.x) && (-1_000...1_000).contains(key.z) && height.isFinite && abs(height) < 100
              }) else { throw ScanArchiveError.invalidScan }
    }
}
