import MetalKit
import Observation

@MainActor
@Observable
final class SavedScanModel {
    let scan: SavedScan
    var settings = DisplaySettings()
    private(set) var renderedDots = 0
    private(set) var renderingError: String?
    @ObservationIgnored private let processor = TerrainProcessor()
    @ObservationIgnored private var renderer: SavedMetalRenderer?
    @ObservationIgnored private var orbit = OrbitCamera()
    @ObservationIgnored private weak var view: MTKView?
    @ObservationIgnored private var revision = 0

    init(scan: SavedScan) { self.scan = scan }

    func attach(_ view: MTKView) {
        self.view = view
        do { renderer = try SavedMetalRenderer(view: view) }
        catch { renderingError = "The 3D view couldn’t start: \(error.localizedDescription)" }
        fit()
        Task { await rebuild() }
    }

    func rebuild() async {
        revision += 1
        let current = revision, settings = settings
        let geometry = await processor.geometry(scan.snapshot, settings: settings)
        guard current == revision, !Task.isCancelled else { return }
        renderer?.update(geometry, settings: settings)
        renderedDots = geometry.dots.count
        updateCamera()
    }

    func fit() {
        let size = view?.bounds.size ?? .zero
        let aspect = size.height > 0 ? Float(size.width / size.height) : 0.46
        orbit.fit(scan.snapshot, aspect: aspect)
        updateCamera()
    }

    func rotate(_ translation: CGPoint) {
        orbit.rotate(x: Float(translation.x), y: Float(translation.y))
        updateCamera()
    }

    func pan(_ translation: CGPoint) {
        orbit.pan(x: Float(translation.x), y: Float(translation.y), viewportHeight: Float(view?.bounds.height ?? 800))
        updateCamera()
    }

    func zoom(_ scale: CGFloat) {
        orbit.zoom(scale: Float(scale))
        updateCamera()
    }

    private func updateCamera() {
        renderer?.orbit = orbit
        view?.setNeedsDisplay()
    }
}
