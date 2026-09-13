import MetalKit
import simd

/// A standalone depth-tested renderer, independent of the live AR camera and its scene.
@MainActor
final class SavedMetalRenderer: NSObject, MTKViewDelegate {
    private struct Vertex {
        var position: SIMD4<Float>
        var color: SIMD4<Float>
    }
    private struct Uniforms {
        var transform: simd_float4x4
        var viewport: SIMD4<Float>
    }
    private let device: any MTLDevice
    private let queue: any MTLCommandQueue
    private let pointsPipeline: any MTLRenderPipelineState
    private let surfacePipeline: any MTLRenderPipelineState
    private let depthState: any MTLDepthStencilState
    private var points: (buffer: (any MTLBuffer)?, count: Int) = (nil, 0)
    private var lines: (buffer: (any MTLBuffer)?, count: Int) = (nil, 0)
    private var triangles: (buffer: (any MTLBuffer)?, count: Int) = (nil, 0)
    var orbit = OrbitCamera()

    init(view: MTKView) throws {
        guard let device = view.device, let queue = device.makeCommandQueue() else {
            throw CocoaError(.featureUnsupported)
        }
        self.device = device
        self.queue = queue
        let library = try device.makeLibrary(source: Self.shader, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "terrainVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "surfaceFragment")
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = .depth32Float
        surfacePipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        descriptor.fragmentFunction = library.makeFunction(name: "dotFragment")
        pointsPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let depth = MTLDepthStencilDescriptor()
        depth.depthCompareFunction = .lessEqual
        depth.isDepthWriteEnabled = true
        guard let state = device.makeDepthStencilState(descriptor: depth) else { throw CocoaError(.featureUnsupported) }
        depthState = state
        super.init()
        view.delegate = self
    }

    func update(_ geometry: DisplayGeometry, settings: DisplaySettings) {
        points = buffer(geometry.dots.map { dot in
            let uncertain = settings.showsQuality && dot.observations < 5
            return Vertex(position: SIMD4(dot.position.x, dot.position.y + 0.007, dot.position.z, uncertain ? -1 : 1),
                          color: uncertain ? SIMD4(1, 0.6, 0.15, 1) : SIMD4(0.77, 1, 0.43, 1))
        })
        var lineVertices: [Vertex] = []
        for segment in geometry.grid + geometry.contours {
            let color: SIMD4<Float> = segment.major ? SIMD4(0.77, 1, 0.43, 1) : SIMD4(0.78, 0.86, 0.8, 1)
            for p in [segment.start, segment.end] {
                lineVertices.append(Vertex(position: SIMD4(p.x, p.y + 0.006, p.z, 0), color: color))
            }
        }
        lines = buffer(lineVertices)
        var surface: [Vertex] = []
        if settings.showsMesh {
            for i in stride(from: 0, to: geometry.surfaceTriangles.count, by: 3) {
                let a = geometry.surfaceTriangles[i], b = geometry.surfaceTriangles[i + 1], c = geometry.surfaceTriangles[i + 2]
                let normal = simd_normalize(simd_cross(b - a, c - a))
                let brightness = 0.55 + 0.45 * abs(simd_dot(normal, simd_normalize(SIMD3<Float>(0.3, 1, 0.4))))
                let color = SIMD4<Float>(0.13 * brightness, 0.32 * brightness, 0.19 * brightness, 1)
                for p in [a, b, c] { surface.append(Vertex(position: SIMD4(p.x, p.y, p.z, 0), color: color)) }
            }
        }
        triangles = buffer(surface)
    }

    private func buffer(_ vertices: [Vertex]) -> (buffer: (any MTLBuffer)?, count: Int) {
        guard !vertices.isEmpty else { return (nil, 0) }
        let buffer = vertices.withUnsafeBytes { raw in
            raw.baseAddress.flatMap { device.makeBuffer(bytes: $0, length: raw.count, options: .storageModeShared) }
        }
        return (buffer, vertices.count)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { view.setNeedsDisplay() }

    func draw(in view: MTKView) {
        guard view.drawableSize.width > 0, view.drawableSize.height > 0,
              let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
              let command = queue.makeCommandBuffer(), let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
        var uniforms = Uniforms(transform: orbit.viewProjection(aspect: Float(view.drawableSize.width / view.drawableSize.height)),
                                viewport: SIMD4(Float(view.drawableSize.height), 1 / tan(29 * .pi / 180), 0, 0))
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setDepthStencilState(depthState)
        encoder.setCullMode(.none)
        encoder.setRenderPipelineState(surfacePipeline)
        for (data, primitive) in [(triangles, MTLPrimitiveType.triangle), (lines, .line)] {
            if let buffer = data.buffer {
                encoder.setVertexBuffer(buffer, offset: 0, index: 0)
                encoder.drawPrimitives(type: primitive, vertexStart: 0, vertexCount: data.count)
            }
        }
        if let buffer = points.buffer {
            encoder.setRenderPipelineState(pointsPipeline)
            encoder.setVertexBuffer(buffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: points.count)
        }
        encoder.endEncoding()
        command.present(drawable)
        command.commit()
    }

    private static let shader = """
    #include <metal_stdlib>
    using namespace metal;
    struct Vertex { float4 position; float4 color; };
    struct Uniforms { float4x4 transform; float4 viewport; };
    struct Raster { float4 position [[position]]; float4 color; float size [[point_size]]; float ring [[flat]]; };
    vertex Raster terrainVertex(uint id [[vertex_id]], const device Vertex *vertices [[buffer(0)]], constant Uniforms &u [[buffer(1)]]) {
        Vertex v = vertices[id];
        Raster out;
        out.position = u.transform * float4(v.position.xyz, 1);
        out.color = v.color;
        out.size = clamp(0.007 * u.viewport.x * u.viewport.y / max(out.position.w, 0.01), 4.0, 16.0);
        out.ring = v.position.w < 0 ? 1 : 0;
        return out;
    }
    fragment float4 surfaceFragment(Raster in [[stage_in]]) { return in.color; }
    fragment float4 dotFragment(Raster in [[stage_in]], float2 uv [[point_coord]]) {
        float radius = distance(uv, float2(0.5));
        if (radius > 0.5 || (in.ring > 0 && radius < 0.3)) discard_fragment();
        return in.color;
    }
    """
}
