import SwiftUI

struct ScanHistoryView: View {
    let archive: ScanArchive
    @State private var history: [ScanSummary] = []
    @State private var unreadableCount = 0
    @State private var loading = true
    @State private var opening: UUID?
    @State private var selectedScan: SavedScan?
    @State private var errorMessage = ""
    @State private var showsError = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView("Loading saved scans")
                } else if history.isEmpty {
                    ContentUnavailableView("No saved scans", systemImage: "square.stack.3d.up",
                                           description: Text("Scan a surface, then tap Save to keep it here."))
                } else {
                    List(history) { scan in
                        Button {
                            opening = scan.id
                            Task {
                                defer { opening = nil }
                                do { selectedScan = try await archive.load(scan.id) }
                                catch { errorMessage = error.localizedDescription; showsError = true }
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "square.3.layers.3d").font(.title2).foregroundStyle(.green)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(scan.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.headline)
                                    Text("\(scan.area.formatted(.number.precision(.fractionLength(1)))) m² · \(scan.pointCount) samples\(scan.isDemo ? " · Demo" : "")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if opening == scan.id { ProgressView() } else { Image(systemName: "chevron.right").foregroundStyle(.secondary) }
                            }.padding(.vertical, 6)
                        }
                        .disabled(opening != nil)
                        .accessibilityIdentifier("Saved scan row")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if unreadableCount > 0 {
                    Text("\(unreadableCount) saved files could not be read. They have not been changed.")
                        .font(.caption).padding().background(.bar)
                }
            }
            .navigationTitle("Scan history")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task {
                defer { loading = false }
                do {
                    let result = try await archive.history()
                    history = result.scans
                    unreadableCount = result.unreadableCount
                } catch { errorMessage = error.localizedDescription; showsError = true }
            }
            .alert("Couldn’t open scans", isPresented: $showsError) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage) }
            .fullScreenCover(item: $selectedScan) { SavedScanView(scan: $0) }
        }
        .preferredColorScheme(.dark)
    }
}
