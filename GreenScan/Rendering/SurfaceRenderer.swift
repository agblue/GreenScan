import RealityKit
import UIKit
import simd

@MainActor
final class SurfaceRenderer {
    let anchor = AnchorEntity(world: .zero)
    private let content = Entity()
    private let dots = Entity()
    var isDemo = false
    private var geometry = DisplayGeometry()
    private var settings = DisplaySettings()
    private var lastCamera = SIMD3<Float>(repeating: 100)

    init() {
        anchor.addChild(content)
        anchor.addChild(dots)
    }

    func clear() {
        geometry = DisplayGeometry()
        content.children.removeAll()
        dots.children.removeAll()
    }

    func update(_ geometry: DisplayGeometry, settings: DisplaySettings, camera: SIMD3<Float>) {
        self.geometry = geometry
        self.settings = settings
        rebuild(camera: camera)
        rebuildSurface()
    }

    func updateViewpoint(_ camera: SIMD3<Float>) {
        guard simd_distance(camera, lastCamera) > 0.25 else { return }
        rebuild(camera: camera)
    }

    private func rebuild(camera: SIMD3<Float>) {
        lastCamera = camera
        dots.children.removeAll()
        // Four distance bands keep material count small; dots use true world-space positions.
        for band in 0..<4 {
            var vertices: [SIMD3<Float>] = []
            var indices: [UInt32] = []
            var tentativeVertices: [SIMD3<Float>] = []
            var tentativeIndices: [UInt32] = []
            for dot in geometry.dots {
                let distance = simd_distance(dot.position, camera)
                let dotBand = min(3, Int(distance / 1.5))
                guard dotBand == band, distance < 8 else { continue }
                let radius = max(0.0035, min(0.008, distance * 0.0018))
                if settings.showsQuality && dot.observations < 5 {
                    appendRing(dot.position, radius: radius * 1.5, vertices: &tentativeVertices, indices: &tentativeIndices)
                } else {
                    appendDot(dot.position, radius: radius, vertices: &vertices, indices: &indices)
                }
            }
            let alpha = CGFloat([1.0, 0.85, 0.65, 0.4][band])
            addMesh(vertices, indices: indices, color: UIColor(red: 0.77, green: 1, blue: 0.43, alpha: alpha), parent: dots)
            addMesh(tentativeVertices, indices: tentativeIndices, color: UIColor.systemOrange.withAlphaComponent(alpha), parent: dots)
        }
    }

    private func rebuildSurface() {
        content.children.removeAll()
        addLines(geometry.grid, width: 0.0008, color: UIColor.white.withAlphaComponent(0.45))
        addLines(geometry.contours.filter { !$0.major }, width: 0.0018, color: UIColor.white.withAlphaComponent(0.85))
        addLines(geometry.contours.filter(\.major), width: 0.003, color: UIColor(red: 0.77, green: 1, blue: 0.43, alpha: 1))
        // The measured terrain hides overlays behind rises without flattening the measured field.
        if !geometry.surfaceTriangles.isEmpty {
            var descriptor = MeshDescriptor(name: "Terrain occlusion")
            descriptor.positions = MeshBuffers.Positions(geometry.surfaceTriangles)
            descriptor.primitives = .triangles((0..<geometry.surfaceTriangles.count).map(UInt32.init))
            if let mesh = try? MeshResource.generate(from: [descriptor]) {
                let materials: [any Material] = (settings.showsMesh || isDemo) ? [UnlitMaterial(color: UIColor(red: 0.09, green: 0.19, blue: 0.12, alpha: 1))] : [OcclusionMaterial()]
                let entity = ModelEntity(mesh: mesh, materials: materials)
                content.addChild(entity)
            }
        }
    }

    private func appendDot(_ point: SIMD3<Float>, radius: Float, vertices: inout [SIMD3<Float>], indices: inout [UInt32]) {
        let center = point + SIMD3<Float>(0, 0.007, 0)
        let base = UInt32(vertices.count)
        vertices += [center + SIMD3(radius, 0, 0), center + SIMD3(-radius, 0, 0),
                     center + SIMD3(0, radius, 0), center + SIMD3(0, -radius, 0),
                     center + SIMD3(0, 0, radius), center + SIMD3(0, 0, -radius)]
        indices += [0, 2, 4, 4, 2, 1, 1, 2, 5, 5, 2, 0, 4, 3, 0, 1, 3, 4, 5, 3, 1, 0, 3, 5].map { base + UInt32($0) }
    }

    private func appendRing(_ point: SIMD3<Float>, radius: Float, vertices: inout [SIMD3<Float>], indices: inout [UInt32]) {
        let center = point + SIMD3<Float>(0, 0.007, 0)
        for step in 0..<12 {
            let a = Float(step) * .pi / 6, b = Float(step + 1) * .pi / 6
            let base = UInt32(vertices.count)
            for (angle, scale) in [(a, Float(0.65)), (a, Float(1)), (b, Float(0.65)), (b, Float(1))] {
                vertices.append(center + SIMD3(cos(angle) * radius * scale, 0, sin(angle) * radius * scale))
            }
            indices += [0, 1, 2, 1, 3, 2].map { base + UInt32($0) }
        }
    }

    private func addLines(_ lines: [SurfaceSegment], width: Float, color: UIColor) {
        var vertices: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        for line in lines {
            let delta = line.end - line.start
            guard simd_length(delta) > 0.00001 else { continue }
            let side = simd_normalize(SIMD3<Float>(-delta.z, 0, delta.x)) * width
            let lift = SIMD3<Float>(0, 0.006, 0)
            let base = UInt32(vertices.count)
            vertices += [line.start - side + lift, line.start + side + lift, line.end - side + lift, line.end + side + lift]
            indices += [0, 1, 2, 1, 3, 2, 2, 1, 0, 2, 3, 1].map { base + UInt32($0) }
        }
        addMesh(vertices, indices: indices, color: color)
    }

    private func addMesh(_ vertices: [SIMD3<Float>], indices: [UInt32], color: UIColor, parent: Entity? = nil) {
        guard !vertices.isEmpty else { return }
        var descriptor = MeshDescriptor(name: "Surface overlay")
        descriptor.positions = MeshBuffers.Positions(vertices)
        descriptor.primitives = .triangles(indices)
        let mesh: MeshResource
        do { mesh = try MeshResource.generate(from: [descriptor]) }
        catch { return }
        var material = UnlitMaterial(color: color)
        material.blending = .transparent(opacity: .init(floatLiteral: Float(color.cgColor.alpha)))
        material.faceCulling = .none
        (parent ?? content).addChild(ModelEntity(mesh: mesh, materials: [material]))
    }
}
