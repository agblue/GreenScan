import Foundation
import simd

struct OrbitCamera: Sendable {
    var target = SIMD3<Float>.zero
    var yaw: Float = 0
    var pitch: Float = 0.7
    var distance: Float = 3
    private(set) var fittedDistance: Float = 3

    var position: SIMD3<Float> {
        target + SIMD3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
    }

    func viewProjection(aspect: Float) -> simd_float4x4 {
        let forward = simd_normalize(target - position)
        let right = simd_normalize(simd_cross(forward, SIMD3<Float>(0, 1, 0)))
        let up = simd_cross(right, forward)
        let view = simd_float4x4(columns: (
            SIMD4(right.x, up.x, -forward.x, 0),
            SIMD4(right.y, up.y, -forward.y, 0),
            SIMD4(right.z, up.z, -forward.z, 0),
            SIMD4(-simd_dot(right, position), -simd_dot(up, position), simd_dot(forward, position), 1)))
        let sy = 1 / tan(Float(29 * Double.pi / 180))
        let near: Float = 0.01, far: Float = 2_000
        let projection = simd_float4x4(columns: (
            SIMD4(sy / max(aspect, 0.1), 0, 0, 0), SIMD4(0, sy, 0, 0),
            SIMD4(0, 0, far / (near - far), -1), SIMD4(0, 0, near * far / (near - far), 0)))
        return projection * view
    }

    mutating func fit(_ snapshot: TerrainSnapshot, aspect: Float) {
        guard let first = snapshot.heights.first else { return }
        var low = TerrainGeometry.position(first.key, first.value)
        var high = low
        for (key, height) in snapshot.heights {
            let point = TerrainGeometry.position(key, height)
            low = simd_min(low, point)
            high = simd_max(high, point)
        }
        target = (low + high) / 2
        let radius = max(0.15, simd_length(high - low) / 2)
        let halfAngle = min(Float(29 * Double.pi / 180), atan(tan(Float(29 * Double.pi / 180)) * max(0.2, aspect)))
        fittedDistance = radius / sin(halfAngle) * 1.1
        distance = fittedDistance
        yaw = 0
        pitch = 0.7
    }

    mutating func rotate(x: Float, y: Float) {
        yaw -= x * 0.008
        pitch = max(-1.4, min(1.4, pitch + y * 0.008))
    }

    mutating func pan(x: Float, y: Float, viewportHeight: Float) {
        let scale = 2 * distance * tan(Float(29 * Double.pi / 180)) / max(viewportHeight, 1)
        let right = SIMD3<Float>(cos(yaw), 0, -sin(yaw))
        let up = SIMD3<Float>(-sin(yaw) * sin(pitch), cos(pitch), -cos(yaw) * sin(pitch))
        target += (-right * x + up * y) * scale
    }

    mutating func zoom(scale: Float) {
        guard scale.isFinite, scale > 0 else { return }
        distance = max(0.08, min(max(10, fittedDistance * 4), distance / scale))
    }
}
