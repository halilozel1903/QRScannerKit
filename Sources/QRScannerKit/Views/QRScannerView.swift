#if os(iOS)
import SwiftUI

/// A full-screen QR code and barcode scanner.
///
/// It picks the best camera path on its own: VisionKit's `DataScannerViewController` where the
/// device supports it, an `AVCaptureMetadataOutput` session everywhere else. It asks for camera
/// access, explains a denied or restricted camera (with a button to Settings), and on devices
/// without a camera offers to scan a photo instead.
///
/// ```swift
/// QRScannerView { result in
///     if case .url(let url) = result.payload { openURL(url) }
/// }
/// ```
///
/// `onResult` is called on the main actor for every new code. The same code is ignored for
/// `ScannerConfiguration.duplicateInterval` seconds, so a code held in front of the camera is
/// delivered once.
public struct QRScannerView: View {
    private let configuration: ScannerConfiguration
    private let source: ScannerSource
    private let onCancel: (() -> Void)?
    private let onResult: (ScanResult) -> Void

    @State private var model = ScannerModel()
    @State private var pinchBase: Double?
    @Environment(\.scenePhase) private var scenePhase

    /// - Parameters:
    ///   - configuration: Symbologies, duplicate interval, viewfinder and buttons.
    ///   - source: `.camera` (default), `.captureSession`, or `.preview(_:)` for previews and
    ///     screenshots.
    ///   - onCancel: Shows a close button that calls this closure. `nil` hides the button.
    ///   - onResult: Called with every new code.
    public init(
        configuration: ScannerConfiguration = ScannerConfiguration(),
        source: ScannerSource = .camera,
        onCancel: (() -> Void)? = nil,
        onResult: @escaping (ScanResult) -> Void
    ) {
        self.configuration = configuration
        self.source = source
        self.onCancel = onCancel
        self.onResult = onResult
    }

    /// A scanner for the given symbologies with the default configuration.
    public init(
        symbologies: Set<Symbology>,
        source: ScannerSource = .camera,
        onCancel: (() -> Void)? = nil,
        onResult: @escaping (ScanResult) -> Void
    ) {
        self.init(
            configuration: ScannerConfiguration(symbologies: symbologies),
            source: source,
            onCancel: onCancel,
            onResult: onResult
        )
    }

    public var body: some View {
        ZStack {
            GeometryReader { proxy in
                let size = proxy.size
                let viewfinder = configuration.viewfinder.rect(in: size)
                ZStack {
                    Color.black
                    if !model.isResolved {
                        Color.black
                    } else if model.permission.canScan {
                        camera(size: size, viewfinder: viewfinder)
                        ViewfinderOverlay(
                            size: size,
                            rect: viewfinder,
                            isSuccess: model.isShowingSuccess,
                            prompt: configuration.prompt
                        )
                    } else {
                        unavailableBackground(size: size)
                    }
                }
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .gesture(magnification)
            }
            .ignoresSafeArea()

            if model.isResolved, !model.permission.canScan {
                PermissionView(
                    permission: model.permission,
                    showsPhotoPicker: configuration.showsPhotoPicker,
                    symbologies: configuration.symbologies,
                    onRequestAccess: { Task { await model.requestAccess(source: source, configuration: configuration) } },
                    onOpenSettings: { CameraAccess.openSettings() },
                    onPhotoResult: { model.deliver($0) },
                    onNoCode: { model.show(notice: "No code found in this photo") }
                )
            }

            ScannerControls(model: model, configuration: configuration, onCancel: onCancel)
        }
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        .task {
            await model.prepare(source: source, configuration: configuration)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                model.refresh(source: source, configuration: configuration)
            }
        }
        .onChange(of: model.deliveredCount) {
            if let result = model.lastResult {
                onResult(result)
            }
        }
        .sensoryFeedback(.success, trigger: model.deliveredCount) { _, _ in
            configuration.hapticFeedback
        }
    }

    @ViewBuilder
    private func camera(size: CGSize, viewfinder: CGRect) -> some View {
        let region = configuration.restrictsToViewfinder ? viewfinder : nil
        switch model.backend {
        case .dataScanner:
            DataScannerBackend(
                model: model,
                symbologies: configuration.symbologies,
                regionOfInterest: region,
                zoomFactor: model.zoomFactor,
                isTorchOn: model.isTorchOn
            )
        case .captureSession:
            CaptureSessionBackend(
                model: model,
                symbologies: configuration.symbologies,
                regionOfInterest: region,
                zoomFactor: model.zoomFactor,
                isTorchOn: model.isTorchOn
            )
        case .preview:
            if let preview = source.previewScanner {
                PreviewBackend(scanner: preview, model: model, size: size, viewfinder: viewfinder)
            }
        case .none:
            Color.black
        }
    }

    @ViewBuilder
    private func unavailableBackground(size: CGSize) -> some View {
        if let backdrop = source.previewScanner?.backdrop {
            PreviewBackdrop(image: backdrop, size: size)
                .blur(radius: 24)
                .overlay(Color.black.opacity(0.55))
        } else {
            LinearGradient(
                colors: [Color(white: 0.16), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    /// Pinch to zoom, on top of the zoom buttons.
    private var magnification: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard model.permission.canScan else { return }
                let base = pinchBase ?? model.zoomFactor
                if pinchBase == nil { pinchBase = base }
                model.setZoom(base * Double(value.magnification))
            }
            .onEnded { _ in
                pinchBase = nil
            }
    }
}
#endif
