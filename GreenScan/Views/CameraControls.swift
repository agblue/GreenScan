import SwiftUI

struct CameraControls: View {
    @Bindable var model: ScanModel

    var body: some View {
        Section {
            Toggle("Live camera", systemImage: "camera", isOn: $model.showsLiveView)
            LabeledContent("Camera opacity", value: "\(Int((model.liveOpacity * 100).rounded()))%")
            Slider(value: $model.liveOpacity, in: 0...1) {
                Text("Camera opacity")
            } minimumValueLabel: { Text("Hidden") } maximumValueLabel: { Text("Full") }
            .disabled(!model.showsLiveView)
            .accessibilityValue("\(Int((model.liveOpacity * 100).rounded())) percent")
        } header: { Text("Live background") } footer: {
            Text("Dim or hide the camera image while keeping the terrain overlays bright. Camera tracking and scanning remain active.")
        }
    }
}
