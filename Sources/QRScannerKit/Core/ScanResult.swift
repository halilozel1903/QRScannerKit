import CoreGraphics
import Foundation

/// One code the scanner read: the raw string, its symbology, what it means and where it was.
public struct ScanResult: Identifiable, Equatable, Hashable, Sendable {
    /// Where a result came from.
    public enum Source: String, Hashable, Sendable {
        /// The live camera (VisionKit or AVFoundation).
        case camera
        /// A photo or image scanned with Vision.
        case image
        /// A `PreviewScanner`, for previews, screenshots and tests.
        case preview
    }

    public let id: UUID
    /// The string encoded in the code.
    public let string: String
    public let symbology: Symbology
    /// The parsed meaning of `string`.
    public let payload: ScanPayload
    /// Where the code was, normalized to 0...1 with the origin at the top left of the camera view
    /// or image. `nil` when unknown.
    public let bounds: CGRect?
    public let source: Source
    public let date: Date

    public init(
        id: UUID = UUID(),
        string: String,
        symbology: Symbology = .qr,
        bounds: CGRect? = nil,
        source: Source = .camera,
        date: Date = Date()
    ) {
        self.id = id
        self.string = string
        self.symbology = symbology
        self.payload = ScanPayload(parsing: string)
        self.bounds = bounds
        self.source = source
        self.date = date
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
