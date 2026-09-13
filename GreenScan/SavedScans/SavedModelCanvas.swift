import MetalKit
import SwiftUI

/// Exact finger counts require UIKit gesture recognizers on the 3D canvas.
struct SavedModelCanvas: UIViewRepresentable {
    let model: SavedScanModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor = MTLClearColor(red: 0.025, green: 0.045, blue: 0.035, alpha: 1)
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        model.attach(view)
        let rotate = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.rotate(_:)))
        rotate.minimumNumberOfTouches = 1
        rotate.maximumNumberOfTouches = 1
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pinch(_:)))
        for recognizer in [rotate, pan, pinch] {
            recognizer.delegate = context.coordinator
            view.addGestureRecognizer(recognizer)
        }
        view.accessibilityIdentifier = "Saved terrain canvas"
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let model: SavedScanModel
        init(model: SavedScanModel) { self.model = model }

        @objc func rotate(_ gesture: UIPanGestureRecognizer) {
            model.rotate(gesture.translation(in: gesture.view))
            gesture.setTranslation(.zero, in: gesture.view)
        }

        @objc func pan(_ gesture: UIPanGestureRecognizer) {
            model.pan(gesture.translation(in: gesture.view))
            gesture.setTranslation(.zero, in: gesture.view)
        }

        @objc func pinch(_ gesture: UIPinchGestureRecognizer) {
            model.zoom(gesture.scale)
            gesture.scale = 1
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            gestureRecognizer is UIPinchGestureRecognizer || otherGestureRecognizer is UIPinchGestureRecognizer
        }
    }
}
