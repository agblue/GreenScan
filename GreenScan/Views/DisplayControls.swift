import SwiftUI

struct DisplayControls: View {
    @Binding var settings: DisplaySettings
    var liveModel: ScanModel? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let liveModel { CameraControls(model: liveModel) }
                Section("Surface layers") {
                    Toggle("Surface dots", systemImage: "circle.grid.3x3.fill", isOn: $settings.showsDots)
                    Toggle("Elevation contours", systemImage: "map", isOn: $settings.showsContours)
                    Toggle("Surface mesh", systemImage: "square.3.layers.3d", isOn: $settings.showsMesh)
                    Toggle("Grid connections", systemImage: "squareshape.split.3x3", isOn: $settings.showsGrid)
                    Toggle("Measurement quality", systemImage: "checkmark.shield", isOn: $settings.showsQuality)
                }
                Section {
                    LabeledContent("Dot spacing", value: "\(Int((settings.spacing * 100).rounded())) cm")
                    Slider(value: $settings.spacing, in: 0.05...0.30, step: 0.05) {
                        Text("Dot spacing")
                    } minimumValueLabel: { Text("Dense") } maximumValueLabel: { Text("Sparse") }
                    .accessibilityValue("\(Int((settings.spacing * 100).rounded())) centimeters")
                } header: { Text("Grid density") } footer: {
                    Text("Display spacing changes the view, not measurement accuracy. Adjust it even while scanning is paused.")
                }
                Section {
                    Picker("Elevation interval", selection: $settings.contourInterval) {
                        Text("1 cm").tag(Float(0.01))
                        Text("2 cm").tag(Float(0.02))
                        Text("5 cm").tag(Float(0.05))
                        Text("10 cm").tag(Float(0.10))
                    }
                } header: { Text("Contours") } footer: {
                    Text("Lines connect equal heights relative to the scan’s starting elevation. Every fifth line is stronger. Fine intervals can show sensor noise; spacing is not an accuracy guarantee.")
                }
                Section("Reading the scan") {
                    Label("Lime dots: observed surface", systemImage: "circle.fill")
                    Label("Orange rings: fewer viewpoints, when quality is on", systemImage: "circle.lefthalf.filled")
                    Text("Blank areas need more coverage. Scan from above, then pause and lower the phone to inspect. Quality reflects repeated observations, not a certified error bound.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Display layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(.green)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
