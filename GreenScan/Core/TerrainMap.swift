import Foundation
import simd

/// A gravity-aligned height field. The X/Z lattice never moves within a scan.
struct TerrainMap: Sendable {
    static let cellSize: Float = 0.05
    static let maximumCells = 32_000
    private(set) var cells: [GridKey: TerrainCell] = [:]
    private(set) var reference: Float?
    private var revision = 0

    mutating func integrate(_ samples: [DepthSample], camera: SIMD3<Float>, time: Double) {
        // One robust measurement per cell per frame, rather than overweighting dense pixels.
        var buckets: [GridKey: [DepthSample]] = [:]
        for sample in samples {
            let p = sample.position
            guard p.x.isFinite, p.y.isFinite, p.z.isFinite, sample.weight > 0,
                  abs(p.x) < 50, abs(p.z) < 50,
                  p.y < camera.y - 0.12 else { continue }
            let key = GridKey(x: Int((p.x / Self.cellSize).rounded()), z: Int((p.z / Self.cellSize).rounded()))
            buckets[key, default: []].append(sample)
        }
        if reference == nil {
            let heights = samples.map(\.position.y).filter { $0.isFinite && $0 < camera.y - 0.25 }.sorted()
            guard heights.count >= 30 else { return }
            reference = heights[heights.count / 2]
        }
        guard let reference else { return }
        for (key, bucket) in buckets {
            let sorted = bucket.sorted { $0.position.y < $1.position.y }
            let median = sorted[sorted.count / 2]
            let y = median.position.y
            // This is a local putting-surface prototype, not a multi-story scene mapper.
            guard abs(y - reference) < 0.65 else { continue }
            if var cell = cells[key] {
                // Repeated frames from essentially the same position are not new evidence.
                guard simd_distance(cell.lastCamera, camera) > 0.06 else { continue }
                guard time > cell.lastTime else { continue }
                let residual = abs(y - cell.height)
                if residual > 0.035 {
                    if let pending = cell.pendingHeight, abs(y - pending) < 0.015 {
                        cell.pendingCount += 1
                        cell.pendingHeight = pending * 0.7 + y * 0.3
                    } else {
                        cell.pendingHeight = y
                        cell.pendingCount = 1
                    }
                    // Credible repeated corrections can replace an early mistaken surface.
                    if cell.pendingCount >= 4, let pending = cell.pendingHeight {
                        cell.height = pending
                        cell.weight = median.weight
                        cell.observations = 2
                        cell.pendingCount = 0
                        cell.pendingHeight = nil
                    }
                } else {
                    let oldWeight = min(cell.weight, 12)
                    cell.height = (cell.height * oldWeight + y * median.weight) / (oldWeight + median.weight)
                    cell.weight = min(oldWeight + median.weight, 12)
                    cell.observations = min(cell.observations + 1, 100)
                    cell.pendingCount = 0
                    cell.pendingHeight = nil
                }
                cell.lastCamera = camera
                cell.lastTime = time
                cells[key] = cell
            } else if cells.count < Self.maximumCells {
                cells[key] = TerrainCell(height: y, weight: median.weight, observations: 1, lastCamera: camera, lastTime: time)
            }
        }
        revision += 1
    }

    func snapshot() -> TerrainSnapshot {
        var heights: [GridKey: Float] = [:]
        var quality: [GridKey: Int] = [:]
        for (key, cell) in cells where cell.observations >= 2 {
            // Edge-preserving local smoothing; no filling across missing cells.
            var sum = cell.height * 4
            var weight: Float = 4
            var neighbors = 0
            for dz in -1...1 {
                for dx in -1...1 where dx != 0 || dz != 0 {
                    if let adjacent = cells[key.offset(dx, dz)], adjacent.observations >= 2,
                       abs(adjacent.height - cell.height) < 0.035 {
                        sum += adjacent.height
                        weight += 1
                        neighbors += 1
                    }
                }
            }
            guard neighbors >= 2 else { continue }
            heights[key] = sum / weight
            quality[key] = cell.observations
        }
        return TerrainSnapshot(heights: heights, quality: quality, reference: reference ?? 0,
                               revision: revision, atCapacity: cells.count >= Self.maximumCells)
    }
}
