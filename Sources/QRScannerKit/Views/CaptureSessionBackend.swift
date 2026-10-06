#if os(iOS)
@preconcurrency import AVFoundation
import SwiftUI

/// The live camera through `AVCaptureSession` and `AVCaptureMetadataOutput`: the fallback for
/// devices without VisionKit's data scanner, and the choice for `ScannerSource.captureSession`.
struct CaptureSessionBackend: UIViewRepresentable {
    let model: ScannerModel
    let symbologies: Set<Symbology>
    /// The viewfinder in view coordinates, or `nil` to scan the whole picture.
    let regionOfInterest: CGRect?
    let zoomFactor: Double
    let isTorchOn: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> CapturePreviewView {
        let view = CapturePreviewView()
        let camera = context.coordinator.camera
        let scannerModel = model
        view.previewLayer.session = camera.session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.regionOfInterest = regionOfInterest
        view.onRegionChange = { rect in camera.setRectOfInterest(rect) }

        camera.onDetect = { [weak view] codes in
            guard let view else { return }
            let size = view.bounds.size
            for code in codes {
                let rect = view.previewLayer.layerRectConverted(fromMetadataOutputRect: code.bounds)
                scannerModel.receive(code.string, symbology: code.symbology, bounds: RegionOfInterest.normalized(rect, in: size), source: .camera)
            }
        }
        camera.start(symbologies: symbologies) { [weak view] info in
            guard let info else { return }
            scannerModel.maxZoomFactor = info.maxZoomFactor
            // The region can only be converted once the session runs.
            view?.setNeedsLayout()
        }
        return view
    }

    func updateUIView(_ view: CapturePreviewView, context: Context) {
        if view.regionOfInterest != regionOfInterest {
            view.regionOfInterest = regionOfInterest
        }
        let coordinator = context.coordinator
        if coordinator.appliedZoom != zoomFactor {
            coordinator.appliedZoom = zoomFactor
            coordinator.camera.setZoom(zoomFactor)
        }
        if coordinator.appliedTorch != isTorchOn {
            coordinator.appliedTorch = isTorchOn
            coordinator.camera.setTorch(isTorchOn)
        }
    }

    static func dismantleUIView(_ view: CapturePreviewView, coordinator: Coordinator) {
        coordinator.camera.onDetect = nil
        coordinator.camera.stop()
    }

    @MainActor
    final class Coordinator {
        let camera = CaptureCamera()
        var appliedZoom: Double = 1
        var appliedTorch = false
    }
}

/// A view whose layer shows the camera.
final class CapturePreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // swiftlint:disable:next force_cast
        layer as! AVCaptureVideoPreviewLayer
    }

    /// The viewfinder in this view's coordinates.
    var regionOfInterest: CGRect? {
        didSet { setNeedsLayout() }
    }

    /// Receives the region converted to metadata-output coordinates.
    var onRegionChange: ((CGRect) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateRotation()
        guard previewLayer.session?.isRunning == true else { return }
        let full = CGRect(x: 0, y: 0, width: 1, height: 1)
        guard let region = regionOfInterest, !bounds.isEmpty else {
            onRegionChange?(full)
            return
        }
        let converted = previewLayer.metadataOutputRectConverted(fromLayerRect: region)
        let valid = converted.isNull || converted.isEmpty || !converted.width.isFinite ? full : converted.intersection(full)
        onRegionChange?(valid.isEmpty ? full : valid)
    }

    /// Keeps the picture upright when an iPad rotates.
    private func updateRotation() {
        guard let connection = previewLayer.connection, let scene = window?.windowScene else { return }
        let angle: CGFloat = switch scene.interfaceOrientation {
        case .landscapeLeft: 180
        case .landscapeRight: 0
        case .portraitUpsideDown: 270
        default: 90
        }
        if connection.videoRotationAngle != angle, connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }
}

/// A code found by `AVCaptureMetadataOutput`, with its bounds in metadata-output coordinates.
struct DetectedCode: Sendable {
    let string: String
    let symbology: Symbology
    let bounds: CGRect
}

/// Hardware facts reported once the session runs.
struct CaptureInfo: Sendable {
    let maxZoomFactor: Double
}

/// Owns the capture session. Every session call runs on one serial queue, as AVFoundation
/// recommends, so the class is safe to share.
final class CaptureCamera: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let output = AVCaptureMetadataOutput()
    private let queue = DispatchQueue(label: "QRScannerKit.CaptureCamera")
    private var device: AVCaptureDevice?
    private var isConfigured = false

    private let lock = NSLock()
    private var _onDetect: (@MainActor @Sendable ([DetectedCode]) -> Void)?

    /// Called on the main actor with the codes in each frame.
    var onDetect: (@MainActor @Sendable ([DetectedCode]) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _onDetect
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _onDetect = newValue
        }
    }

    func start(symbologies: Set<Symbology>, completion: @escaping @MainActor @Sendable (CaptureInfo?) -> Void) {
        queue.async {
            let info = self.configure(symbologies: symbologies)
            if info != nil, !self.session.isRunning {
                self.session.startRunning()
            }
            Task { @MainActor in completion(info) }
        }
    }

    func stop() {
        queue.async {
            if let device = self.device, device.hasTorch, device.torchMode != .off, (try? device.lockForConfiguration()) != nil {
                device.torchMode = .off
                device.unlockForConfiguration()
            }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func setRectOfInterest(_ rect: CGRect) {
        queue.async {
            if self.output.rectOfInterest != rect {
                self.output.rectOfInterest = rect
            }
        }
    }

    func setTorch(_ isOn: Bool) {
        queue.async {
            guard let device = self.device, device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
            device.torchMode = isOn ? .on : .off
            device.unlockForConfiguration()
        }
    }

    func setZoom(_ factor: Double) {
        queue.async {
            guard let device = self.device, (try? device.lockForConfiguration()) != nil else { return }
            let limit = min(device.activeFormat.videoMaxZoomFactor, 10)
            device.videoZoomFactor = min(max(CGFloat(factor), device.minAvailableVideoZoomFactor), limit)
            device.unlockForConfiguration()
        }
    }

    /// Adds the back camera and the metadata output once. Runs on `queue`.
    private func configure(symbologies: Set<Symbology>) -> CaptureInfo? {
        if isConfigured, let device {
            return CaptureInfo(maxZoomFactor: Double(min(device.activeFormat.videoMaxZoomFactor, 10)))
        }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return nil }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }
        guard session.canAddInput(input), session.canAddOutput(output) else { return nil }
        session.addInput(input)
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: queue)
        let wanted = symbologies.sorted { $0.rawValue < $1.rawValue }.flatMap(\.metadataObjectTypes)
        output.metadataObjectTypes = wanted.filter { output.availableMetadataObjectTypes.contains($0) }

        self.device = device
        isConfigured = true
        return CaptureInfo(maxZoomFactor: Double(min(device.activeFormat.videoMaxZoomFactor, 10)))
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        let codes = metadataObjects.compactMap { object -> DetectedCode? in
            guard let code = object as? AVMetadataMachineReadableCodeObject,
                  let string = code.stringValue,
                  let symbology = Symbology(metadataObjectType: code.type)
            else { return nil }
            return DetectedCode(string: string, symbology: symbology, bounds: code.bounds)
        }
        guard !codes.isEmpty, let onDetect else { return }
        Task { @MainActor in onDetect(codes) }
    }
}

extension Symbology {
    /// Creates the symbology for an `AVMetadataObject.ObjectType`.
    init?(metadataObjectType type: AVMetadataObject.ObjectType) {
        switch type {
        case .qr: self = .qr
        case .microQR: self = .microQR
        case .aztec: self = .aztec
        case .dataMatrix: self = .dataMatrix
        case .pdf417: self = .pdf417
        case .microPDF417: self = .microPDF417
        case .code39, .code39Mod43: self = .code39
        case .code93: self = .code93
        case .code128: self = .code128
        case .ean8: self = .ean8
        case .ean13: self = .ean13
        case .upce: self = .upce
        case .itf14: self = .itf14
        case .interleaved2of5: self = .interleaved2of5
        case .codabar: self = .codabar
        case .gs1DataBar, .gs1DataBarExpanded, .gs1DataBarLimited: self = .gs1DataBar
        default: return nil
        }
    }

    /// The metadata object types that read this symbology.
    var metadataObjectTypes: [AVMetadataObject.ObjectType] {
        switch self {
        case .qr: [.qr]
        case .microQR: [.microQR]
        case .aztec: [.aztec]
        case .dataMatrix: [.dataMatrix]
        case .pdf417: [.pdf417]
        case .microPDF417: [.microPDF417]
        case .code39: [.code39, .code39Mod43]
        case .code93: [.code93]
        case .code128: [.code128]
        case .ean8: [.ean8]
        case .ean13: [.ean13]
        case .upce: [.upce]
        case .itf14: [.itf14]
        case .interleaved2of5: [.interleaved2of5]
        case .codabar: [.codabar]
        case .gs1DataBar: [.gs1DataBar, .gs1DataBarExpanded, .gs1DataBarLimited]
        }
    }
}
#endif
