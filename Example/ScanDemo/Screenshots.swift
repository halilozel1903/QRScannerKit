import QRScannerKit
import SwiftUI

/// Scenes used by CI to capture the README screenshots on iPhone and iPad.
/// Launch with `-screenshot <scene>`; normal launches are unaffected.
enum ScreenshotScene: String {
    /// The viewfinder over the café table, with the Wi-Fi card inside it.
    case scanning
    /// The parsed Wi-Fi result in a sheet over the scanner, with the Join button.
    case result
    /// The scanner when camera access was denied, with the Settings button.
    case permission

    static var current: ScreenshotScene? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return ScreenshotScene(rawValue: arguments[index + 1])
    }
}

/// Renders one scene with a `PreviewScanner`: the simulator has no camera, so a drawing of a café
/// table stands in for the camera picture. Everything else is the real scanner UI.
struct ScreenshotView: View {
    let scene: ScreenshotScene

    @State private var backdrop: UIImage?

    private let configuration = ScannerConfiguration(symbologies: [.qr])

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let backdrop {
                content(backdrop: backdrop)
                    .task {
                        // Tells scripts/screenshots.sh that the scene is on screen.
                        let marker = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("screenshot-ready")
                        try? await Task.sleep(for: .seconds(1.5))
                        try? scene.rawValue.write(to: marker, atomically: true, encoding: .utf8)
                    }
            }
        }
        .background {
            // The scanner fills the whole screen, so the table is drawn for the whole screen and
            // the printed code lands inside the scanner's viewfinder.
            GeometryReader { proxy in
                let size = proxy.size
                Color.clear
                    .task(id: size) {
                        guard size.width > 0, size.height > 0 else { return }
                        backdrop = DeskBackdrop.render(
                            size: size,
                            viewfinder: configuration.viewfinder.rect(in: size)
                        )
                    }
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func content(backdrop: UIImage) -> some View {
        switch scene {
        case .scanning:
            QRScannerView(
                configuration: configuration,
                source: .preview(PreviewScanner(backdrop: backdrop)),
                onCancel: {},
                onResult: { _ in }
            )
        case .result:
            QRScannerView(
                configuration: configuration,
                source: .preview(PreviewScanner(backdrop: backdrop)),
                onCancel: {},
                onResult: { _ in }
            )
            .sheet(isPresented: .constant(true)) {
                ResultSheet(result: ScanResult(string: DeskBackdrop.wifiPayload, symbology: .qr))
                    .presentationDetents([.height(560), .large])
                    .interactiveDismissDisabled()
            }
        case .permission:
            QRScannerView(
                configuration: configuration,
                source: .preview(PreviewScanner(backdrop: backdrop, permission: .denied)),
                onCancel: {},
                onResult: { _ in }
            )
        }
    }
}
