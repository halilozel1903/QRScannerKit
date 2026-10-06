#if os(iOS)
import CoreGraphics
import Foundation
import Observation
import VisionKit

/// The state behind one `QRScannerView`: permission, the running scanner, torch, zoom and the
/// last delivered code.
@MainActor
@Observable
final class ScannerModel {
    enum Backend: Equatable {
        case none
        case dataScanner
        case captureSession
        case preview
    }

    private(set) var permission: CameraPermission = .notDetermined
    private(set) var backend: Backend = .none
    /// `false` until the permission was read for the first time.
    private(set) var isResolved = false
    private(set) var isTorchAvailable = false
    var isTorchOn = false
    private(set) var zoomFactor: Double = 1
    var maxZoomFactor: Double = 1
    private(set) var lastResult: ScanResult?
    /// Increases with every delivered code; drives `onResult` and the haptic.
    private(set) var deliveredCount = 0
    /// `true` for a moment after a code was delivered: the viewfinder turns green.
    private(set) var isShowingSuccess = false
    /// A short message such as "No code found in this photo".
    private(set) var notice: String?

    @ObservationIgnored private var filter = DuplicateFilter()
    @ObservationIgnored private var successTask: Task<Void, Never>?
    @ObservationIgnored private var noticeTask: Task<Void, Never>?

    /// Decides which scanner runs, asking for camera access first if needed.
    func prepare(source: ScannerSource, configuration: ScannerConfiguration) async {
        filter.interval = configuration.duplicateInterval
        resolve(source: source, configuration: configuration)
        if permission == .notDetermined, configuration.requestsAccessAutomatically, !source.isPreview {
            await requestAccess(source: source, configuration: configuration)
        }
    }

    func requestAccess(source: ScannerSource, configuration: ScannerConfiguration) async {
        guard !source.isPreview else { return }
        _ = await CameraAccess.requestAccess()
        resolve(source: source, configuration: configuration)
    }

    /// Reads the permission again, for example after the user came back from Settings.
    func refresh(source: ScannerSource, configuration: ScannerConfiguration) {
        guard !permission.canScan else { return }
        resolve(source: source, configuration: configuration)
    }

    private func resolve(source: ScannerSource, configuration: ScannerConfiguration) {
        defer { isResolved = true }
        switch source {
        case .preview(let preview):
            permission = preview.permission
            backend = preview.permission.canScan ? .preview : .none
            isTorchAvailable = preview.hasTorch
            maxZoomFactor = max(1, preview.maxZoomFactor)
        case .camera, .captureSession:
            permission = CameraAccess.permission
            guard permission.canScan else {
                backend = .none
                return
            }
            let usesDataScanner = source.allowsDataScanner
                && configuration.prefersDataScanner
                && DataScannerViewController.isSupported
                && DataScannerViewController.isAvailable
            backend = usesDataScanner ? .dataScanner : .captureSession
            isTorchAvailable = CameraAccess.isTorchAvailable
        }
    }

    // MARK: - Codes

    /// Delivers a code from the camera unless the same one was delivered a moment ago.
    func receive(_ string: String, symbology: Symbology, bounds: CGRect?, source: ScanResult.Source) {
        guard filter.accept(string, symbology: symbology) else { return }
        deliver(ScanResult(string: string, symbology: symbology, bounds: bounds, source: source))
    }

    /// Delivers a result without duplicate filtering, for photos.
    func deliver(_ result: ScanResult) {
        lastResult = result
        deliveredCount += 1
        isShowingSuccess = true
        successTask?.cancel()
        successTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            self?.isShowingSuccess = false
        }
    }

    func show(notice text: String) {
        notice = text
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }

    /// VisionKit stopped, for example because the camera was taken by another app or access was
    /// revoked.
    func scannerBecameUnavailable() {
        permission = CameraAccess.permission
        if !permission.canScan { backend = .none }
    }

    // MARK: - Camera controls

    func toggleTorch() {
        isTorchOn.toggle()
    }

    func setZoom(_ factor: Double) {
        zoomFactor = min(max(factor, 1), max(1, maxZoomFactor))
    }
}

extension ScannerSource {
    var isPreview: Bool {
        if case .preview = self { return true }
        return false
    }

    var allowsDataScanner: Bool {
        if case .camera = self { return true }
        return false
    }

    var previewScanner: PreviewScanner? {
        if case .preview(let scanner) = self { return scanner }
        return nil
    }
}
#endif
