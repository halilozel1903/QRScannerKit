import Foundation
import Observation
import QRScannerKit

/// The codes scanned in this session, newest first.
@MainActor
@Observable
final class ScanHistory {
    private(set) var results: [ScanResult] = []

    func add(_ result: ScanResult) {
        results.removeAll { $0.string == result.string && $0.symbology == result.symbology }
        results.insert(result, at: 0)
    }

    func remove(atOffsets offsets: IndexSet) {
        results.remove(atOffsets: offsets)
    }
}
