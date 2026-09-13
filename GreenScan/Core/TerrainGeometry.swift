import Foundation
import simd

/// Pure geometry generation shared by live scans, demo mode, and tests.
enum TerrainGeometry {
    static func build(_ snapshot: TerrainSnapshot, settings: DisplaySettings) -> DisplayGeometry {
        var result = DisplayGeometry()
        let stride = max(1, Int((settings.spacing / TerrainMap.cellSize).rounded()))
        for (key, height) in snapshot.heights {
            let point = position(key, height)
            if key.x % stride == 0, key.z % stride == 0 {
                if settings.showsDots {
                    result.dots.append(SurfacePoint(position: point, observations: snapshot.quality[key] ?? 0))
                }
                if settings.showsGrid {
                    for (dx, dz) in [(stride, 0), (0, stride)] {
                        // Do not connect lines across holes in the scan.
                        let complete = (1...stride).allSatisfy {
                            snapshot.heights[key.offset(dx == 0 ? 0 : $0, dz == 0 ? 0 : $0)] != nil
                        }
                        if complete, let endHeight = snapshot.heights[key.offset(dx, dz)] {
                            result.grid.append(SurfaceSegment(start: point, end: position(key.offset(dx, dz), endHeight), major: false))
                        }
                    }
                }
            }
            let keys = [key, key.offset(1, 0), key.offset(1, 1), key.offset(0, 1)]
            let corners = keys.compactMap { k in snapshot.heights[k].map { position(k, $0) } }
            guard corners.count == 4,
                  let low = corners.map(\.y).min(), let high = corners.map(\.y).max(), high - low < 0.08 else { continue }
            for indices in [[0, 2, 1], [0, 3, 2]] {
                let triangle = indices.map { corners[$0] }
                result.surfaceTriangles.append(contentsOf: triangle)
                if settings.showsContours {
                    result.contours.append(contentsOf: contours(triangle, reference: snapshot.reference, interval: settings.contourInterval))
                }
            }
        }
        return result
    }

    static func position(_ key: GridKey, _ y: Float) -> SIMD3<Float> {
        SIMD3(Float(key.x) * TerrainMap.cellSize, y, Float(key.z) * TerrainMap.cellSize)
    }

    static func contours(_ triangle: [SIMD3<Float>], reference: Float, interval: Float) -> [SurfaceSegment] {
        guard triangle.count == 3, interval >= 0.005,
              let low = triangle.map(\.y).min(), let high = triangle.map(\.y).max(), high > low else { return [] }
        let first = Int(ceil((low - reference) / interval))
        let last = Int(floor((high - reference) / interval))
        guard first <= last, last - first < 100 else { return [] }
        var segments: [SurfaceSegment] = []
        for index in first...last {
            let level = reference + Float(index) * interval
            var crossings: [SIMD3<Float>] = []
            for edge in 0..<3 {
                let a = triangle[edge], b = triangle[(edge + 1) % 3]
                // Half-open rule avoids duplicate vertex crossings.
                if (a.y <= level && b.y > level) || (b.y <= level && a.y > level) {
                    crossings.append(a + (b - a) * ((level - a.y) / (b.y - a.y)))
                }
            }
            if crossings.count == 2, simd_distance(crossings[0], crossings[1]) > 0.00001 {
                segments.append(SurfaceSegment(start: crossings[0], end: crossings[1], major: index % 5 == 0))
            }
        }
        return segments
    }

    static func demo() -> TerrainSnapshot {
        var heights: [GridKey: Float] = [:]
        var quality: [GridKey: Int] = [:]
        for x in -35...35 {
            for z in -80...5 {
                let px = Float(x) * TerrainMap.cellSize, pz = Float(z) * TerrainMap.cellSize
                let height = -1.1 + 0.018 * px + 0.11 * exp(-((px - 0.25) * (px - 0.25) + (pz + 2) * (pz + 2)) / 0.85)
                let key = GridKey(x: x, z: z)
                heights[key] = height
                quality[key] = 8
            }
        }
        return TerrainSnapshot(heights: heights, quality: quality, reference: -1.1, revision: 1, atCapacity: false)
    }
}
