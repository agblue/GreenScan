import Foundation
import simd

struct DepthSample: Sendable {
    let position: SIMD3<Float>
    let weight: Float
}
