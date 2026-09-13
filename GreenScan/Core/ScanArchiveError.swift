import Foundation

enum ScanArchiveError: LocalizedError {
    case invalidScan

    var errorDescription: String? {
        "This scan is empty, damaged, or uses an unsupported format."
    }
}
