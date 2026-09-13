import Foundation

struct ScanSummary: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let isDemo: Bool
    let area: Float
    let pointCount: Int
}
