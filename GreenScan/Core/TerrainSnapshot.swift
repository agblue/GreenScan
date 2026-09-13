import Foundation
import simd

struct TerrainSnapshot: Codable, Sendable {
    static let empty = TerrainSnapshot(heights: [:], quality: [:], reference: 0, revision: 0, atCapacity: false)
    let heights: [GridKey: Float]
    let quality: [GridKey: Int]
    let reference: Float
    let revision: Int
    let atCapacity: Bool
    var area: Float { Float(heights.count) * TerrainMap.cellSize * TerrainMap.cellSize }
}
