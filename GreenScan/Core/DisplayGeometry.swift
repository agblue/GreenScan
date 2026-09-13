import Foundation
import simd

struct DisplayGeometry: Sendable {
    var dots: [SurfacePoint] = []
    var grid: [SurfaceSegment] = []
    var contours: [SurfaceSegment] = []
    var surfaceTriangles: [SIMD3<Float>] = []
}
