import SwiftUI

struct SavedScanView: View {
    @State private var model: SavedScanModel
    @State private var showsLayers = false
    @Environment(\.dismiss) private var dismiss

    init(scan: SavedScan) { _model = State(initialValue: SavedScanModel(scan: scan)) }

    var body: some View {
        NavigationStack {
            SavedModelCanvas(model: model)
                .ignoresSafeArea(edges: .bottom)
                .overlay {
                    if let error = model.renderingError { ContentUnavailableView("Unable to display terrain", systemImage: "exclamationmark.triangle", description: Text(error)) }
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 12) {
                        Text("\(model.renderedDots) dots").font(.caption).foregroundStyle(.secondary)
                            .accessibilityIdentifier("Saved dot count")
                        Text("Drag to rotate · two fingers to pan · pinch to zoom")
                            .font(.caption).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 20) {
                            Button("Layers", systemImage: "slider.horizontal.3") { showsLayers = true }
                                .accessibilityIdentifier("Saved layers")
                            Spacer()
                            Button("Zoom out", systemImage: "minus.magnifyingglass") { model.zoom(0.8) }
                                .labelStyle(.iconOnly)
                            Button("Zoom in", systemImage: "plus.magnifyingglass") { model.zoom(1.25) }
                                .labelStyle(.iconOnly)
                            Button("Fit", systemImage: "arrow.up.left.and.arrow.down.right") { model.fit() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
                .navigationTitle("Saved surface")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Text(model.scan.isDemo ? "DEMO" : model.scan.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
        }
        .preferredColorScheme(.dark)
        .tint(Color(red: 0.77, green: 1, blue: 0.43))
        .task(id: model.settings) { await model.rebuild() }
        .sheet(isPresented: $showsLayers) { DisplayControls(settings: $model.settings) }
    }
}
