import Vision

extension Symbology {
    /// Creates the symbology for a Vision barcode symbology. Checksum and full-ASCII variants map
    /// to their base symbology.
    public init?(vision symbology: VNBarcodeSymbology) {
        switch symbology {
        case .qr: self = .qr
        case .microQR: self = .microQR
        case .aztec: self = .aztec
        case .dataMatrix: self = .dataMatrix
        case .pdf417: self = .pdf417
        case .microPDF417: self = .microPDF417
        case .code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum: self = .code39
        case .code93, .code93i: self = .code93
        case .code128: self = .code128
        case .ean8: self = .ean8
        case .ean13: self = .ean13
        case .upce: self = .upce
        case .itf14: self = .itf14
        case .i2of5, .i2of5Checksum: self = .interleaved2of5
        case .codabar: self = .codabar
        case .gs1DataBar, .gs1DataBarExpanded, .gs1DataBarLimited: self = .gs1DataBar
        default: return nil
        }
    }

    /// The Vision symbologies that read this symbology, variants included.
    public var visionSymbologies: [VNBarcodeSymbology] {
        switch self {
        case .qr: [.qr]
        case .microQR: [.microQR]
        case .aztec: [.aztec]
        case .dataMatrix: [.dataMatrix]
        case .pdf417: [.pdf417]
        case .microPDF417: [.microPDF417]
        case .code39: [.code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum]
        case .code93: [.code93, .code93i]
        case .code128: [.code128]
        case .ean8: [.ean8]
        case .ean13: [.ean13]
        case .upce: [.upce]
        case .itf14: [.itf14]
        case .interleaved2of5: [.i2of5, .i2of5Checksum]
        case .codabar: [.codabar]
        case .gs1DataBar: [.gs1DataBar, .gs1DataBarExpanded, .gs1DataBarLimited]
        }
    }
}

extension Set where Element == Symbology {
    /// Every Vision symbology for the set, in a stable order.
    var visionSymbologies: [VNBarcodeSymbology] {
        sorted { $0.rawValue < $1.rawValue }.flatMap(\.visionSymbologies)
    }
}
