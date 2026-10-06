#if os(iOS)
import UIKit

/// Where a `QRScannerView` gets its picture from.
public enum ScannerSource {
    /// The back camera: VisionKit's `DataScannerViewController` where supported, otherwise an
    /// `AVCaptureMetadataOutput` session.
    case camera
    /// The back camera through `AVCaptureMetadataOutput`, even where VisionKit is available.
    case captureSession
    /// A still image instead of the camera, for SwiftUI previews, screenshots, UI tests and the
    /// simulator.
    case preview(PreviewScanner)
}

/// A fake camera: shows a still image behind the viewfinder and, if you like, "finds" codes on a
/// timer. Permission states can be simulated too, so every screen of the scanner can be
/// previewed without a device.
///
/// ```swift
/// #Preview {
///     QRScannerView(source: .preview(PreviewScanner(
///         backdrop: UIImage(named: "Desk"),
///         simulatedCodes: ["WIFI:T:WPA;S:Guest;P:welcome;;"]
///     ))) { result in print(result.payload) }
/// }
/// ```
public struct PreviewScanner {
    /// The picture shown instead of the camera, scaled to fill. `nil` shows a dark gradient.
    public var backdrop: UIImage?
    /// The permission the scanner pretends to have.
    public var permission: CameraPermission
    /// Codes delivered one after another, `delay` apart.
    public var simulatedCodes: [String]
    public var symbology: Symbology
    public var delay: Duration
    /// Whether the torch button is shown. Turning it on brightens the backdrop.
    public var hasTorch: Bool
    /// The largest zoom factor. Zooming scales the backdrop around the viewfinder.
    public var maxZoomFactor: Double

    public init(
        backdrop: UIImage? = nil,
        permission: CameraPermission = .authorized,
        simulatedCodes: [String] = [],
        symbology: Symbology = .qr,
        delay: Duration = .seconds(2),
        hasTorch: Bool = true,
        maxZoomFactor: Double = 5
    ) {
        self.backdrop = backdrop
        self.permission = permission
        self.simulatedCodes = simulatedCodes
        self.symbology = symbology
        self.delay = delay
        self.hasTorch = hasTorch
        self.maxZoomFactor = maxZoomFactor
    }
}
#endif
