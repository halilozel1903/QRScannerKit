import Foundation

/// How a `QRScannerView` scans and what it shows.
public struct ScannerConfiguration: Sendable {
    /// The codes to read. QR codes only by default.
    public var symbologies: Set<Symbology>
    /// The same code is delivered again only after this many seconds.
    public var duplicateInterval: TimeInterval
    /// Plays a success haptic for every delivered code.
    public var hapticFeedback: Bool
    /// Reads codes inside the viewfinder only. When `false` the whole camera image is scanned.
    public var restrictsToViewfinder: Bool
    /// Size and position of the viewfinder.
    public var viewfinder: ViewfinderLayout
    /// The hint under the viewfinder. `nil` hides it.
    public var prompt: String?
    public var showsTorchButton: Bool
    public var showsZoomControls: Bool
    /// Zoom factors offered as buttons, filtered by what the camera supports.
    public var zoomFactors: [Double]
    /// Shows a button that scans a code from the photo library.
    public var showsPhotoPicker: Bool
    /// Asks for camera access as soon as the scanner appears. When `false` the scanner explains
    /// why it needs the camera and waits for a tap.
    public var requestsAccessAutomatically: Bool
    /// Uses VisionKit's `DataScannerViewController` where it is supported. When `false`, or on
    /// devices without it, an `AVCaptureMetadataOutput` session scans instead.
    public var prefersDataScanner: Bool

    public init(
        symbologies: Set<Symbology> = [.qr],
        duplicateInterval: TimeInterval = 2,
        hapticFeedback: Bool = true,
        restrictsToViewfinder: Bool = true,
        viewfinder: ViewfinderLayout? = nil,
        prompt: String? = nil,
        showsTorchButton: Bool = true,
        showsZoomControls: Bool = true,
        zoomFactors: [Double] = [1, 2, 4],
        showsPhotoPicker: Bool = true,
        requestsAccessAutomatically: Bool = true,
        prefersDataScanner: Bool = true
    ) {
        self.symbologies = symbologies.isEmpty ? [.qr] : symbologies
        self.duplicateInterval = duplicateInterval
        self.hapticFeedback = hapticFeedback
        self.restrictsToViewfinder = restrictsToViewfinder
        let onlyLinear = self.symbologies.allSatisfy { !$0.isTwoDimensional }
        self.viewfinder = viewfinder ?? (onlyLinear ? .wide : .square)
        self.prompt = prompt ?? Self.defaultPrompt(for: self.symbologies)
        self.showsTorchButton = showsTorchButton
        self.showsZoomControls = showsZoomControls
        self.zoomFactors = zoomFactors
        self.showsPhotoPicker = showsPhotoPicker
        self.requestsAccessAutomatically = requestsAccessAutomatically
        self.prefersDataScanner = prefersDataScanner
    }

    /// "Point the camera at a QR code", "… at a barcode" or "… at a code".
    static func defaultPrompt(for symbologies: Set<Symbology>) -> String {
        if symbologies == [.qr] { return "Point the camera at a QR code" }
        if symbologies.allSatisfy({ !$0.isTwoDimensional }) { return "Point the camera at a barcode" }
        return "Point the camera at a code"
    }
}
