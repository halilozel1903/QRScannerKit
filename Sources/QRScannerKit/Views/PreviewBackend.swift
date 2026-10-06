#if os(iOS)
import SwiftUI

/// Shows a `PreviewScanner`'s still image where the camera picture would be.
struct PreviewBackend: View {
    let scanner: PreviewScanner
    let model: ScannerModel
    let size: CGSize
    let viewfinder: CGRect

    var body: some View {
        PreviewBackdrop(image: scanner.backdrop, size: size)
            .scaleEffect(model.zoomFactor, anchor: zoomAnchor)
            .brightness(model.isTorchOn ? 0.12 : 0)
            .frame(width: size.width, height: size.height)
            .clipped()
            .animation(.easeInOut(duration: 0.25), value: model.zoomFactor)
            .animation(.easeInOut(duration: 0.2), value: model.isTorchOn)
            .task {
                for code in scanner.simulatedCodes {
                    try? await Task.sleep(for: scanner.delay)
                    guard !Task.isCancelled else { return }
                    model.receive(
                        code,
                        symbology: scanner.symbology,
                        bounds: RegionOfInterest.normalized(viewfinder, in: size),
                        source: .preview
                    )
                }
            }
            .accessibilityHidden(true)
    }

    private var zoomAnchor: UnitPoint {
        guard size.width > 0, size.height > 0 else { return .center }
        return UnitPoint(x: viewfinder.midX / size.width, y: viewfinder.midY / size.height)
    }
}

/// The still image, or a dark gradient when there is none.
struct PreviewBackdrop: View {
    let image: UIImage?
    let size: CGSize

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
        } else {
            LinearGradient(
                colors: [Color(white: 0.22), Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: size.width, height: size.height)
        }
    }
}
#endif
