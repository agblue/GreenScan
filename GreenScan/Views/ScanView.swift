import SwiftUI

struct ScanView: View {
    @State private var model = ScanModel()
    @State private var showsControls = false
    @State private var showsHistory = false
    @State private var savedScan: SavedScan?
    @State private var saving = false
    @State private var saveError = ""
    @State private var showsSaveError = false
    @State private var archive = ScanArchive()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    private let accent = Color(red: 0.77, green: 1, blue: 0.43)

    var body: some View {
        ZStack {
            CameraView(model: model).ignoresSafeArea()
                .accessibilityLabel("Live surface visualization")
            LinearGradient(colors: [.black.opacity(0.65), .clear, .clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea().allowsHitTesting(false)
            if model.unsupported || model.cameraDenied {
                unavailableView
            } else {
                VStack(spacing: 0) {
                    header
                    Spacer()
                    if model.sampleCount == 0 && !model.needsReset {
                        Image(systemName: "viewfinder")
                            .font(.largeTitle)
                            .foregroundStyle(accent.opacity(0.7))
                            .accessibilityHidden(true)
                    }
                    Spacer()
                    controls
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .accessibilityHidden(model.inspectingSavedScan)
        .preferredColorScheme(.dark)
        .task { await model.start() }
        .task(id: model.settings) { await model.displayChanged() }
        .onChange(of: scenePhase) { _, phase in model.setActive(phase == .active) }
        .onChange(of: model.demoAngle) { _, _ in model.updateDemoViewpoint() }
        .onChange(of: model.showsLiveView) { _, _ in model.updateLiveBackground() }
        .onChange(of: model.liveOpacity) { _, _ in model.updateLiveBackground() }
        .fullScreenCover(item: $savedScan, onDismiss: { model.inspectingSavedScan = false }) { SavedScanView(scan: $0) }
        .sheet(isPresented: $showsHistory, onDismiss: { model.inspectingSavedScan = false }) { ScanHistoryView(archive: archive) }
        .alert("Couldn’t save scan", isPresented: $showsSaveError) {
            Button("OK", role: .cancel) {}
        } message: { Text(saveError) }
        .sheet(isPresented: $showsControls) { DisplayControls(settings: $model.settings, liveModel: model) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("GREENSCAN").font(.headline).tracking(3)
                    Text(model.isDemo ? "DEMO · SYNTHETIC TERRAIN" : "SURFACE EXPLORER")
                        .font(.caption2).tracking(1.8).foregroundStyle(accent)
                }
                Spacer()
                Button("History", systemImage: "clock.arrow.circlepath") { openHistory() }
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 48)
                    .background(.ultraThinMaterial, in: .circle)
                Button("Layers", systemImage: "slider.horizontal.3") { showsControls = true }
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial, in: .circle)
            }
            HStack(spacing: 8) {
                Image(systemName: model.paused ? "pause.circle.fill" : model.trackingReady ? "dot.radiowaves.left.and.right" : "viewfinder")
                    .foregroundStyle(accent)
                Text(model.status).font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(.ultraThinMaterial, in: .capsule)
            .accessibilityElement(children: .combine)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.isDemo {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Explore viewpoint").font(.caption)
                    Slider(value: $model.demoAngle, in: -2.5...2.5) { Text("Demo viewpoint") }
                        .tint(accent)
                }
            }
            if model.sampleCount > 0 {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.snapshot.area, format: .number.precision(.fractionLength(1)))
                        .font(.title2.weight(.semibold)).monospacedDigit()
                    Text("m² mapped").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int((model.settings.spacing * 100).rounded())) cm grid").font(.caption).foregroundStyle(accent)
                }
                Text(model.qualityText).font(.caption).foregroundStyle(.secondary)
            }
            Text(model.guidance)
                .font(.subheadline).foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button(model.paused ? "Resume Scan" : "Pause Scan", systemImage: model.paused ? "play.fill" : "pause.fill") {
                    model.togglePause()
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 54)
                .foregroundStyle(.black)
                .background(accent, in: .rect(cornerRadius: 18))
                .disabled(model.needsReset || model.sessionFailed)
                Button { Task { await model.reset() } } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 86, minHeight: 54)
                }
                .foregroundStyle(.white)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 18))
            }
            Button(saving ? "Saving…" : "Save", systemImage: "square.and.arrow.down") { save() }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(model.sampleCount == 0 || saving)
            Text("Practice surface preview · accuracy under evaluation")
                .font(.caption2).foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: .infinity)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 26))
    }

    private func openHistory() {
        model.pauseForInspection()
        model.inspectingSavedScan = true
        showsHistory = true
    }

    private func save() {
        guard !saving, model.sampleCount > 0 else { return }
        model.pauseForInspection()
        let captured = SavedScan(snapshot: model.snapshot, isDemo: model.isDemo)
        saving = true
        Task {
            defer { saving = false }
            do {
                try await archive.save(captured)
                model.inspectingSavedScan = true
                savedScan = captured
            } catch {
                saveError = error.localizedDescription
                showsSaveError = true
            }
        }
    }

    private var unavailableView: some View {
        VStack(spacing: 20) {
            Image(systemName: model.cameraDenied ? "camera.fill" : "viewfinder")
                .font(.largeTitle).foregroundStyle(accent)
            Text(model.cameraDenied ? "Let’s see the green" : "A LiDAR iPhone is needed")
                .font(.title2.bold())
            Text(model.cameraDenied ? "Allow camera access in Settings to map the ground and view your scan." :
                    "Live scanning needs a supported iPhone Pro or Pro Max with LiDAR. You can explore a synthetic surface here.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            if model.cameraDenied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }.buttonStyle(.borderedProminent).tint(.green)
            }
            Button("History", systemImage: "clock.arrow.circlepath") { openHistory() }
                .buttonStyle(.bordered)
            Button("Explore Demo", systemImage: "mountain.2") { model.enterDemo() }
                .buttonStyle(.bordered).tint(accent)
        }
        .padding(30)
    }
}
