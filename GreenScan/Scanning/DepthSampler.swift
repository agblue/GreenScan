import ARKit
import simd

@MainActor
enum DepthSampler {
    static func samples(from frame: ARFrame) -> [DepthSample] {
        guard let depth = frame.sceneDepth else { return [] }
        let buffer = depth.depthMap
        guard let confidence = depth.confidenceMap else { return [] }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        CVPixelBufferLockBaseAddress(confidence, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(confidence, .readOnly)
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        }
        guard let depthBase = CVPixelBufferGetBaseAddress(buffer),
              let confidenceBase = CVPixelBufferGetBaseAddress(confidence) else { return [] }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let depthStride = CVPixelBufferGetBytesPerRow(buffer) / MemoryLayout<Float32>.stride
        let confidenceStride = CVPixelBufferGetBytesPerRow(confidence)
        let depths = depthBase.assumingMemoryBound(to: Float32.self)
        let confidences = confidenceBase.assumingMemoryBound(to: UInt8.self)
        let intrinsics = frame.camera.intrinsics
        let scaleX = Float(width) / Float(frame.camera.imageResolution.width)
        let scaleY = Float(height) / Float(frame.camera.imageResolution.height)
        let fx = intrinsics[0][0] * scaleX, fy = intrinsics[1][1] * scaleY
        let cx = intrinsics[2][0] * scaleX, cy = intrinsics[2][1] * scaleY
        var samples: [DepthSample] = []
        samples.reserveCapacity(width * height / 16)
        for y in stride(from: 0, to: height, by: 4) {
            for x in stride(from: 0, to: width, by: 4) {
                let depth = depths[y * depthStride + x]
                let confidence = confidences[y * confidenceStride + x]
                guard confidence >= 1, depth.isFinite, depth > 0.25, depth < 3.5 else { continue }
                // AR camera coordinates look along -Z; image coordinates have +Y down.
                let local = SIMD4<Float>((Float(x) - cx) * depth / fx, -(Float(y) - cy) * depth / fy, -depth, 1)
                let world = frame.camera.transform * local
                samples.append(DepthSample(position: SIMD3(world.x, world.y, world.z), weight: confidence == 2 ? 1 : 0.35))
            }
        }
        return samples
    }
}
