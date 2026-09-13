import Foundation
import simd

struct SurfacePoint: Sendable {
    let position: SIMD3<Float>
    let observations: Int
}
