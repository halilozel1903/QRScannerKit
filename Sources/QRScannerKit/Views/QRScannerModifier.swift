#if os(iOS)
import SwiftUI

extension View {
    /// Presents a full-screen scanner while `isPresented` is `true`. The first code closes it and
    /// is handed to `onResult`; the close button dismisses it without a result.
    ///
    /// ```swift
    /// Button("Scan") { isScanning = true }
    ///     .qrScanner(isPresented: $isScanning) { result in
    ///         lastScan = result
    ///     }
    /// ```
    public func qrScanner(
        isPresented: Binding<Bool>,
        configuration: ScannerConfiguration = ScannerConfiguration(),
        source: ScannerSource = .camera,
        onResult: @escaping (ScanResult) -> Void
    ) -> some View {
        modifier(QRScannerPresenter(
            isPresented: isPresented,
            configuration: configuration,
            source: source,
            onResult: onResult
        ))
    }

    /// Presents a full-screen scanner for the given symbologies.
    public func qrScanner(
        isPresented: Binding<Bool>,
        symbologies: Set<Symbology>,
        onResult: @escaping (ScanResult) -> Void
    ) -> some View {
        qrScanner(
            isPresented: isPresented,
            configuration: ScannerConfiguration(symbologies: symbologies),
            onResult: onResult
        )
    }
}

struct QRScannerPresenter: ViewModifier {
    @Binding var isPresented: Bool
    let configuration: ScannerConfiguration
    let source: ScannerSource
    let onResult: (ScanResult) -> Void

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $isPresented) {
            QRScannerView(
                configuration: configuration,
                source: source,
                onCancel: { isPresented = false },
                onResult: { result in
                    guard isPresented else { return }
                    isPresented = false
                    onResult(result)
                }
            )
        }
    }
}
#endif
