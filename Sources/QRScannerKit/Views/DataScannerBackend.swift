#if os(iOS)
import SwiftUI
import Vision
import VisionKit

/// The live camera through VisionKit's `DataScannerViewController` (A12 Bionic and later).
struct DataScannerBackend: UIViewControllerRepresentable {
    let model: ScannerModel
    let symbologies: Set<Symbology>
    /// The viewfinder in view coordinates, or `nil` to scan the whole picture.
    let regionOfInterest: CGRect?
    let zoomFactor: Double
    let isTorchOn: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: symbologies.visionSymbologies)],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: false,
            isGuidanceEnabled: false,
            isHighlightingEnabled: false
        )
        scanner.delegate = context.coordinator
        context.coordinator.scanner = scanner
        context.coordinator.settings = Coordinator.Settings(region: regionOfInterest, zoom: zoomFactor, torch: isTorchOn)
        context.coordinator.startWhenOnScreen()
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.settings = Coordinator.Settings(region: regionOfInterest, zoom: zoomFactor, torch: isTorchOn)
        context.coordinator.apply()
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        struct Settings: Equatable {
            var region: CGRect?
            var zoom: Double
            var torch: Bool
        }

        let model: ScannerModel
        weak var scanner: DataScannerViewController?
        var settings = Settings(region: nil, zoom: 1, torch: false)
        private var appliedTorch = false
        private var startTask: Task<Void, Never>?

        init(model: ScannerModel) {
            self.model = model
        }

        /// `startScanning()` fails while the view is not in a window yet, so it is retried for a
        /// moment after the view appears.
        func startWhenOnScreen() {
            startTask = Task { [weak self] in
                for _ in 0..<20 {
                    try? await Task.sleep(for: .milliseconds(100))
                    guard let self, !Task.isCancelled, let scanner = self.scanner else { return }
                    if scanner.view.window != nil {
                        self.model.maxZoomFactor = min(scanner.maxZoomFactor, 10)
                        self.apply()
                        if scanner.isScanning { return }
                    }
                }
            }
        }

        func apply() {
            guard let scanner else { return }
            let bounds = scanner.view.bounds
            if let region = settings.region {
                // VisionKit only accepts a region inside its view.
                if !bounds.isEmpty, bounds.insetBy(dx: -1, dy: -1).contains(region), scanner.regionOfInterest != region {
                    scanner.regionOfInterest = region.intersection(bounds)
                }
            } else if scanner.regionOfInterest != nil {
                scanner.regionOfInterest = nil
            }

            let zoom = min(max(settings.zoom, scanner.minZoomFactor), scanner.maxZoomFactor)
            if abs(scanner.zoomFactor - zoom) > 0.001 {
                scanner.zoomFactor = zoom
            }

            if settings.torch != appliedTorch {
                appliedTorch = settings.torch
                CameraAccess.setTorch(settings.torch)
            }

            if !scanner.isScanning, scanner.view.window != nil {
                try? scanner.startScanning()
            }
        }

        func stop() {
            startTask?.cancel()
            scanner?.stopScanning()
            if appliedTorch {
                CameraAccess.setTorch(false)
                appliedTorch = false
            }
        }

        // MARK: DataScannerViewControllerDelegate

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                handle(item, in: dataScanner)
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            handle(item, in: dataScanner)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            model.scannerBecameUnavailable()
        }

        private func handle(_ item: RecognizedItem, in scanner: DataScannerViewController) {
            guard case .barcode(let barcode) = item,
                  let string = barcode.payloadStringValue,
                  let symbology = Symbology(vision: barcode.observation.symbology)
            else { return }
            let corners = [barcode.bounds.topLeft, barcode.bounds.topRight, barcode.bounds.bottomRight, barcode.bounds.bottomLeft]
            let xs = corners.map(\.x)
            let ys = corners.map(\.y)
            let rect = CGRect(
                x: xs.min() ?? 0,
                y: ys.min() ?? 0,
                width: (xs.max() ?? 0) - (xs.min() ?? 0),
                height: (ys.max() ?? 0) - (ys.min() ?? 0)
            )
            model.receive(
                string,
                symbology: symbology,
                bounds: RegionOfInterest.normalized(rect, in: scanner.view.bounds.size),
                source: .camera
            )
        }
    }
}
#endif
