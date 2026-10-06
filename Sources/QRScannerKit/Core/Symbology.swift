import Foundation

/// A kind of machine-readable code: QR, Data Matrix, EAN-13 and so on.
///
/// The same values work with every scanner: the VisionKit data scanner, the AVFoundation
/// fallback and photo scanning with Vision.
public enum Symbology: String, CaseIterable, Codable, Hashable, Sendable {
    case qr
    case microQR
    case aztec
    case dataMatrix
    case pdf417
    case microPDF417
    case code39
    case code93
    case code128
    case ean8
    case ean13
    case upce
    case itf14
    case interleaved2of5
    case codabar
    case gs1DataBar

    /// The name people know the symbology by, for example "QR Code" or "EAN-13".
    public var name: String {
        switch self {
        case .qr: "QR Code"
        case .microQR: "Micro QR"
        case .aztec: "Aztec"
        case .dataMatrix: "Data Matrix"
        case .pdf417: "PDF417"
        case .microPDF417: "MicroPDF417"
        case .code39: "Code 39"
        case .code93: "Code 93"
        case .code128: "Code 128"
        case .ean8: "EAN-8"
        case .ean13: "EAN-13"
        case .upce: "UPC-E"
        case .itf14: "ITF-14"
        case .interleaved2of5: "Interleaved 2 of 5"
        case .codabar: "Codabar"
        case .gs1DataBar: "GS1 DataBar"
        }
    }

    /// `true` for matrix and stacked codes (QR, Aztec, Data Matrix, PDF417), `false` for
    /// one-dimensional barcodes.
    public var isTwoDimensional: Bool {
        switch self {
        case .qr, .microQR, .aztec, .dataMatrix, .pdf417, .microPDF417: true
        default: false
        }
    }

    /// The SF Symbol that fits the symbology: `qrcode` or `barcode`.
    public var systemImage: String {
        isTwoDimensional ? "qrcode" : "barcode"
    }

    /// Every symbology.
    public static let all: Set<Symbology> = Set(allCases)

    /// QR, Micro QR, Aztec, Data Matrix, PDF417 and MicroPDF417.
    public static let twoDimensional: Set<Symbology> = all.filter(\.isTwoDimensional)

    /// One-dimensional barcodes: EAN, UPC, Code 39/93/128, ITF, Codabar and GS1 DataBar.
    public static let linear: Set<Symbology> = all.filter { !$0.isTwoDimensional }

    /// The barcodes printed on retail products: EAN-8, EAN-13 (which includes UPC-A) and UPC-E.
    public static let retail: Set<Symbology> = [.ean8, .ean13, .upce]
}
