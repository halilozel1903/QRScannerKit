import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// Draws QR codes with Core Image, for share sheets, previews and tests.
public enum QRCodeImage {
    /// How much damage the code survives, from 7% (`low`) to 30% (`high`).
    public enum CorrectionLevel: String, Sendable {
        case low = "L", medium = "M", quartile = "Q", high = "H"
    }

    /// Returns a QR code for `string` with sharp modules, `scale` pixels per module.
    public static func make(_ string: String, scale: CGFloat = 10, correction: CorrectionLevel = .medium) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = correction.rawValue
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: max(1, scale), y: max(1, scale)))
        return CIContext(options: [.useSoftwareRenderer: false]).createCGImage(scaled, from: scaled.extent)
    }
}
