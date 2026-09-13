import Foundation
import simd

struct SurfaceSegment: Sendable {
    let start: SIMD3<Float>
    let end: SIMD3<Float>
    let major: Bool
}
