import Foundation

struct ScanHistory: Sendable {
    let scans: [ScanSummary]
    let unreadableCount: Int
}
