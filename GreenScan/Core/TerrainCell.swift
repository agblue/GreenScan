import Foundation
import simd

struct TerrainCell: Sendable {
    var height: Float
    var weight: Float
    var observations: Int
    var lastCamera: SIMD3<Float>
    var lastTime: Double
    var pendingHeight: Float?
    var pendingCount = 0
}
