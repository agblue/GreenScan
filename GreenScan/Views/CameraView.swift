import RealityKit
import SwiftUI

struct CameraView: UIViewRepresentable {
    let model: ScanModel

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        model.attach(view)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
