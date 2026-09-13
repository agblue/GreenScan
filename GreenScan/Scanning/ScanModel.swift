import ARKit
import AVFoundation
import Observation
import RealityKit
import SwiftUI

@MainActor
@Observable
final class ScanModel: NSObject, @preconcurrency ARSessionDelegate {
    var settings = DisplaySettings()
    var showsLiveView = true
    var liveOpacity: Float = 1
    var inspectingSavedScan = false {
        didSet { arView?.isHidden = inspectingSavedScan }
    }
    private(set) var paused = false
    private(set) var trackingReady = false
    private(set) var status = "Getting ready"
    private(set) var guidance = "Point down and slowly sweep across the ground."
    private(set) var snapshot = TerrainSnapshot.empty
    private(set) var cameraDenied = false
    private(set) var unsupported = false
    private(set) var isDemo = false
    private(set) var sessionFailed = false
    private(set) var needsReset = false
    var demoAngle: Double = 0

    @ObservationIgnored let renderer = SurfaceRenderer()
    @ObservationIgnored private let processor = TerrainProcessor()
    @ObservationIgnored private weak var arView: ARView?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var displayRevision = 0
    @ObservationIgnored private var processing = false
    @ObservationIgnored private var lastSampleTime = 0.0
    @ObservationIgnored private var lastViewTime = 0.0
    @ObservationIgnored private var cameraPosition = SIMD3<Float>.zero
    @ObservationIgnored private var active = true
    @ObservationIgnored private var started = false
    @ObservationIgnored private var demoCamera: PerspectiveCamera?

    var sampleCount: Int { snapshot.heights.count }
    var qualityText: String {
        let repeatCount = snapshot.quality.values.filter { $0 >= 5 }.count
        guard sampleCount > 0 else { return "Awaiting coverage" }
        return "\(Int(Float(repeatCount) / Float(sampleCount) * 100))% multi-view coverage"
    }

    func attach(_ view: ARView) {
        arView = view
        view.scene.addAnchor(renderer.anchor)
        view.session.delegateQueue = .main
        view.session.delegate = self
    }

    func start() async {
        guard !started else { return }
        started = true
        if ProcessInfo.processInfo.arguments.contains("--demo") {
            enterDemo()
            return
        }
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else {
            unsupported = true
            status = "LiDAR required"
            return
        }
        let authorization = AVCaptureDevice.authorizationStatus(for: .video)
        let allowed: Bool
        if authorization == .notDetermined {
            allowed = await AVCaptureDevice.requestAccess(for: .video)
        } else {
            allowed = authorization == .authorized
        }
        guard allowed else {
            cameraDenied = true
            status = "Camera access needed"
            return
        }
        if active { runSession(reset: true) }
    }

    private func runSession(reset: Bool) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = [.sceneDepth]
        configuration.worldAlignment = .gravity
        // Deliberately leave plane detection disabled to preserve gentle contours.
        arView?.session.run(configuration, options: reset ? [.resetTracking, .removeExistingAnchors] : [])
        updateLiveBackground()
        sessionFailed = false
        status = "Finding the ground"
    }

    func pauseForInspection() {
        if !paused { togglePause() }
    }

    func updateLiveBackground() {
        guard let arView else { return }
        let opacity = showsLiveView ? max(0, min(1, liveOpacity)) : 0
        if isDemo {
            arView.environment.background = .color(UIColor(red: 0.045 * CGFloat(opacity), green: 0.095 * CGFloat(opacity), blue: 0.07 * CGFloat(opacity), alpha: 1))
        } else if opacity <= 0 {
            arView.environment.background = .color(.black)
        } else {
            // Exposure compensation affects the camera background only, keeping overlays bright.
            arView.environment.background = .cameraFeed(exposureCompensation: log2(opacity))
        }
    }

    func togglePause() {
        paused.toggle()
        // Invalidate any result already in flight so pause freezes the visible snapshot.
        displayRevision += 1
        refreshStatus()
        if !paused && isDemo && snapshot.heights.isEmpty { loadDemo() }
    }

    func reset() async {
        generation += 1
        displayRevision += 1
        paused = false
        needsReset = false
        trackingReady = false
        snapshot = .empty
        renderer.clear()
        lastSampleTime = 0
        await processor.reset(generation: generation)
        if isDemo {
            loadDemo()
        } else if !unsupported && !cameraDenied && active {
            runSession(reset: true)
        }
    }

    func displayChanged() async {
        displayRevision += 1
        let revision = displayRevision
        let generation = generation
        let settings = settings
        let geometry = await processor.geometry(snapshot, settings: settings)
        guard revision == displayRevision, generation == self.generation else { return }
        renderer.update(geometry, settings: settings, camera: cameraPosition)
    }

    func setActive(_ value: Bool) {
        active = value
        if !value {
            displayRevision += 1
            trackingReady = false
            arView?.session.pause()
        } else if cameraDenied && AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            cameraDenied = false
            runSession(reset: true)
        } else if started && !isDemo && !unsupported && !cameraDenied {
            runSession(reset: false)
        }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard active, !isDemo else { return }
        if case .normal = frame.camera.trackingState { trackingReady = true } else { trackingReady = false }
        refreshStatus()
        let translation = frame.camera.transform.columns.3
        cameraPosition = SIMD3(translation.x, translation.y, translation.z)
        if !inspectingSavedScan && frame.timestamp - lastViewTime > 0.3 {
            lastViewTime = frame.timestamp
            renderer.updateViewpoint(cameraPosition)
        }
        guard !inspectingSavedScan, trackingReady, !needsReset, !paused, !processing, frame.timestamp - lastSampleTime > 0.2 else { return }
        lastSampleTime = frame.timestamp
        let samples = DepthSampler.samples(from: frame)
        guard !samples.isEmpty else {
            guidance = "No reliable depth. Point down and move closer to the surface."
            return
        }
        processing = true
        let generation = generation, revision = displayRevision
        let camera = cameraPosition, timestamp = frame.timestamp
        Task {
            defer { processing = false }
            guard let result = await processor.integrate(samples, camera: camera, time: timestamp, generation: generation),
                  generation == self.generation, revision == displayRevision, !paused, active, trackingReady else { return }
            let settings = settings
            let geometry = await processor.geometry(result, settings: settings)
            guard generation == self.generation, revision == displayRevision, !paused, active, trackingReady else { return }
            snapshot = result
            renderer.update(geometry, settings: settings, camera: cameraPosition)
            refreshStatus()
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        trackingReady = false
        displayRevision += 1
        status = "Tracking interrupted"
        guidance = "Keep the app open to recover camera tracking."
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        // Do not silently fuse a potentially shifted coordinate system.
        needsReset = true
        status = "Start a fresh scan"
        guidance = "Tracking was interrupted. Reset to avoid mixing misaligned measurements."
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        sessionFailed = true
        trackingReady = false
        displayRevision += 1
        needsReset = true
        status = "Scan interrupted"
        guidance = "\(error.localizedDescription) Reset to try again."
    }

    private func refreshStatus() {
        guard !needsReset, !sessionFailed else { return }
        if isDemo {
            status = paused ? "Demo paused" : "Demo surface"
            guidance = "Synthetic terrain · drag the viewpoint slider to explore."
        } else if !trackingReady {
            status = paused ? "Paused · tracking limited" : "Tracking limited"
            guidance = "Move slowly and keep previously scanned ground in view."
        } else if paused {
            status = "Scan paused"
            guidance = "Surface frozen. Move around to inspect, or resume to refine."
        } else {
            status = "Scanning"
            guidance = snapshot.atCapacity ? "Map limit reached. Existing areas can still refine; reset for a new area." :
                sampleCount == 0 ? "Sweep the same patch from a second position to reveal dots." : "Walk around the patch to improve coverage."
        }
    }

    func enterDemo() {
        isDemo = true
        renderer.isDemo = true
        unsupported = false
        cameraDenied = false
        arView?.session.pause()
        arView?.cameraMode = .nonAR
        arView?.environment.background = .color(UIColor(red: 0.045, green: 0.095, blue: 0.07, alpha: 1))
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 58
        let cameraAnchor = AnchorEntity(world: .zero)
        cameraAnchor.addChild(camera)
        arView?.scene.addAnchor(cameraAnchor)
        demoCamera = camera
        settings.showsContours = true
        loadDemo()
        updateDemoViewpoint()
    }

    private func loadDemo() {
        snapshot = TerrainGeometry.demo()
        trackingReady = true
        refreshStatus()
        Task { await displayChanged() }
    }

    func updateDemoViewpoint() {
        let angle = Float(demoAngle)
        cameraPosition = SIMD3(sin(angle) * 2.2, 0.3, cos(angle) * 2.2 - 2)
        demoCamera?.look(at: SIMD3(0, -1.05, -2), from: cameraPosition, relativeTo: nil)
        renderer.updateViewpoint(cameraPosition)
    }
}
