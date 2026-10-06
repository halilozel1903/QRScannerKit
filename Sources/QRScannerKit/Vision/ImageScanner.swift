import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Reads codes from photos and other still images with Vision's `VNDetectBarcodesRequest`.
///
/// ```swift
/// // From a PhotosPicker item:
/// if let data = try await item.loadTransferable(type: Data.self) {
///     let results = try await ImageScanner.scan(imageData: data)
/// }
/// ```
///
/// Results are ordered from the largest code to the smallest, with duplicates removed.
public enum ImageScanner {
    /// Errors thrown while reading an image.
    public enum Failure: Error, Hashable, Sendable {
        /// The data is not an image Vision can read.
        case unreadableImage
    }

    /// Scans encoded image data (JPEG, PNG, HEIC…). The EXIF orientation is respected.
    /// Runs off the main actor.
    public static func scan(imageData: Data, symbologies: Set<Symbology> = Symbology.all) async throws -> [ScanResult] {
        try await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { throw ImageScanner.Failure.unreadableImage }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            let rawOrientation = properties?[kCGImagePropertyOrientation] as? UInt32
            let orientation = rawOrientation.flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up
            return try ImageScanner.scan(image, orientation: orientation, symbologies: symbologies)
        }.value
    }

    /// Scans a `CGImage` synchronously. Call it off the main thread for large images.
    public static func scan(
        _ image: CGImage,
        orientation: CGImagePropertyOrientation = .up,
        symbologies: Set<Symbology> = Symbology.all
    ) throws -> [ScanResult] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = symbologies.visionSymbologies
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
        try handler.perform([request])
        let observations = request.results ?? []
        return results(from: observations.map { observation in
            DetectedBarcode(
                string: observation.payloadStringValue,
                symbology: Symbology(vision: observation.symbology),
                boundingBox: observation.boundingBox
            )
        }, allowed: symbologies)
    }

    /// A barcode as Vision reports it: a bottom-left-origin normalized bounding box.
    struct DetectedBarcode: Sendable {
        var string: String?
        var symbology: Symbology?
        var boundingBox: CGRect
    }

    /// Turns detections into results: drops unreadable codes and repeats, converts the bounds
    /// to a top-left origin and sorts the largest code first.
    static func results(from detections: [DetectedBarcode], allowed: Set<Symbology>, date: Date = Date()) -> [ScanResult] {
        var seen = Set<String>()
        return detections
            .sorted { $0.boundingBox.width * $0.boundingBox.height > $1.boundingBox.width * $1.boundingBox.height }
            .compactMap { detection -> ScanResult? in
                guard let string = detection.string, !string.isEmpty,
                      let symbology = detection.symbology, allowed.contains(symbology),
                      seen.insert("\(symbology.rawValue)|\(string)").inserted
                else { return nil }
                return ScanResult(
                    string: string,
                    symbology: symbology,
                    bounds: RegionOfInterest.flipped(detection.boundingBox),
                    source: .image,
                    date: date
                )
            }
    }
}
