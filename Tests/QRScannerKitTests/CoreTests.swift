import CoreGraphics
import Foundation
import Testing
@testable import QRScannerKit

let referenceDate = Date(timeIntervalSince1970: 1_790_000_000)

@Suite("Duplicate filter")
struct DuplicateFilterTests {
    @Test func samePayloadIsDroppedWithinTheInterval() {
        var filter = DuplicateFilter(interval: 2)
        let first = filter.accept("https://example.com", symbology: .qr, at: referenceDate)
        let again = filter.accept("https://example.com", symbology: .qr, at: referenceDate + 1.9)
        let later = filter.accept("https://example.com", symbology: .qr, at: referenceDate + 2)
        #expect(first)
        #expect(!again)
        #expect(later)
    }

    @Test func intervalCountsFromTheLastAcceptedScan() {
        var filter = DuplicateFilter(interval: 2)
        _ = filter.accept("A", symbology: .qr, at: referenceDate)
        let dropped = filter.accept("A", symbology: .qr, at: referenceDate + 1.5)
        let accepted = filter.accept("A", symbology: .qr, at: referenceDate + 2.1)
        let droppedAgain = filter.accept("A", symbology: .qr, at: referenceDate + 3)
        #expect(!dropped)
        #expect(accepted)
        #expect(!droppedAgain)
    }

    @Test func differentPayloadsAndSymbologiesPass() {
        var filter = DuplicateFilter(interval: 5)
        let a = filter.accept("A", symbology: .qr, at: referenceDate)
        let b = filter.accept("B", symbology: .qr, at: referenceDate)
        let aAsEAN = filter.accept("A", symbology: .ean13, at: referenceDate)
        #expect(a && b && aAsEAN)
        #expect(filter.count == 3)
    }

    @Test func wouldAcceptDoesNotRemember() {
        var filter = DuplicateFilter(interval: 2)
        #expect(filter.wouldAccept("A", symbology: .qr, at: referenceDate))
        #expect(filter.count == 0)
        _ = filter.accept("A", symbology: .qr, at: referenceDate)
        #expect(!filter.wouldAccept("A", symbology: .qr, at: referenceDate + 1))
    }

    @Test func zeroIntervalAcceptsEverything() {
        var filter = DuplicateFilter(interval: 0)
        let first = filter.accept("A", symbology: .qr, at: referenceDate)
        let second = filter.accept("A", symbology: .qr, at: referenceDate)
        #expect(first && second)
    }

    @Test func resetForgets() {
        var filter = DuplicateFilter(interval: 10)
        _ = filter.accept("A", symbology: .qr, at: referenceDate)
        filter.reset()
        let accepted = filter.accept("A", symbology: .qr, at: referenceDate + 1)
        #expect(accepted)
    }
}

@Suite("Viewfinder and region of interest")
struct RegionOfInterestTests {
    let phone = CGSize(width: 400, height: 800)

    @Test func squareViewfinderOnAPhone() {
        let rect = ViewfinderLayout.square.rect(in: phone)
        #expect(rect == CGRect(x: 60, y: 220, width: 280, height: 280))
    }

    @Test func viewfinderIsCappedOnIPad() {
        let rect = ViewfinderLayout.square.rect(in: CGSize(width: 1024, height: 1366))
        #expect(rect.width == 320)
        #expect(rect.midX == 512)
    }

    @Test func wideViewfinderStaysInsideAShortView() {
        let size = CGSize(width: 900, height: 200)
        let rect = ViewfinderLayout.wide.rect(in: size)
        #expect(rect.height <= 140.0001)
        #expect(CGRect(origin: .zero, size: size).contains(rect))
        #expect(abs(rect.width / rect.height - 1.8) < 0.001)
    }

    @Test func emptySizeGivesZero() {
        #expect(ViewfinderLayout.square.rect(in: .zero) == .zero)
    }

    @Test func normalizedRect() {
        let rect = RegionOfInterest.normalized(CGRect(x: 100, y: 200, width: 200, height: 400), in: phone)
        #expect(rect == CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
        #expect(RegionOfInterest.denormalized(rect, in: phone) == CGRect(x: 100, y: 200, width: 200, height: 400))
    }

    @Test func normalizedRectIsClipped() {
        let rect = RegionOfInterest.normalized(CGRect(x: -100, y: 700, width: 300, height: 300), in: phone)
        #expect(rect == CGRect(x: 0, y: 0.875, width: 0.5, height: 0.125))
        #expect(RegionOfInterest.normalized(CGRect(x: 500, y: 0, width: 10, height: 10), in: phone) == .zero)
    }

    @Test func aspectFillCropsTheImage() {
        // A 1080×1920 image (9:16) shown in a 400×800 view (1:2) is scaled to 450×800 and
        // 25 points are cut on each side.
        let full = RegionOfInterest.normalizedInImage(
            CGRect(x: 0, y: 0, width: 1, height: 1),
            viewSize: phone,
            imageSize: CGSize(width: 1080, height: 1920)
        )
        #expect(abs(full.minX - 25.0 / 450) < 0.0001)
        #expect(abs(full.width - 400.0 / 450) < 0.0001)
        #expect(full.minY == 0)
        #expect(full.height == 1)
    }

    @Test func viewfinderInTheImage() {
        let viewfinder = RegionOfInterest.normalized(ViewfinderLayout.square.rect(in: phone), in: phone)
        let inImage = RegionOfInterest.normalizedInImage(viewfinder, viewSize: phone, imageSize: CGSize(width: 1080, height: 1920))
        #expect(abs(inImage.midX - 0.5) < 0.0001)
        #expect(abs(inImage.width - 280.0 / 450) < 0.0001)
    }

    @Test func flipIsItsOwnInverse() {
        let rect = CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        let flipped = RegionOfInterest.flipped(rect)
        #expect(abs(flipped.minY - 0.4) < 0.0001)
        let back = RegionOfInterest.flipped(flipped)
        #expect(abs(back.minY - rect.minY) < 0.0001)
        #expect(back.width == rect.width)
    }

    @Test func containsUsesTheCenter() {
        let region = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        #expect(RegionOfInterest.region(region, contains: CGRect(x: 0.1, y: 0.4, width: 0.3, height: 0.1)))
        #expect(!RegionOfInterest.region(region, contains: CGRect(x: 0, y: 0, width: 0.2, height: 0.2)))
    }
}

@Suite("Symbologies, results and configuration")
struct ModelTests {
    @Test func symbologySets() {
        #expect(Symbology.all.count == Symbology.allCases.count)
        #expect(Symbology.twoDimensional.contains(.qr))
        #expect(!Symbology.twoDimensional.contains(.ean13))
        #expect(Symbology.linear.union(Symbology.twoDimensional) == Symbology.all)
        #expect(Symbology.ean13.name == "EAN-13")
        #expect(Symbology.qr.systemImage == "qrcode")
        #expect(Symbology.code128.systemImage == "barcode")
    }

    @Test func visionMappingRoundTrips() {
        for symbology in Symbology.allCases {
            for vision in symbology.visionSymbologies {
                #expect(Symbology(vision: vision) == symbology)
            }
        }
    }

    @Test func resultParsesItsString() {
        let result = ScanResult(string: "tel:+15551234567", symbology: .qr, source: .image)
        #expect(result.payload == .phone("+15551234567"))
        #expect(result.source == .image)
    }

    @Test func configurationDefaults() {
        let qr = ScannerConfiguration()
        #expect(qr.symbologies == [.qr])
        #expect(qr.viewfinder == .square)
        #expect(qr.prompt == "Point the camera at a QR code")

        let retail = ScannerConfiguration(symbologies: Symbology.retail)
        #expect(retail.viewfinder == .wide)
        #expect(retail.prompt == "Point the camera at a barcode")

        let empty = ScannerConfiguration(symbologies: [])
        #expect(empty.symbologies == [.qr])
    }

    @Test func permissionFlags() {
        #expect(CameraPermission.authorized.canScan)
        #expect(!CameraPermission.denied.canScan)
        #expect(CameraPermission.denied.canOpenSettings)
        #expect(!CameraPermission.restricted.canOpenSettings)
    }
}

@Suite("Image scanning")
struct ImageScannerTests {
    @Test func detectionsBecomeResults() {
        let detections = [
            ImageScanner.DetectedBarcode(string: "small", symbology: .qr, boundingBox: CGRect(x: 0, y: 0, width: 0.1, height: 0.1)),
            ImageScanner.DetectedBarcode(string: "large", symbology: .qr, boundingBox: CGRect(x: 0.2, y: 0.1, width: 0.5, height: 0.5)),
            ImageScanner.DetectedBarcode(string: "large", symbology: .qr, boundingBox: CGRect(x: 0.2, y: 0.1, width: 0.4, height: 0.4)),
            ImageScanner.DetectedBarcode(string: nil, symbology: .qr, boundingBox: CGRect(x: 0, y: 0, width: 0.9, height: 0.9)),
            ImageScanner.DetectedBarcode(string: "4006381333931", symbology: .ean13, boundingBox: CGRect(x: 0, y: 0, width: 0.2, height: 0.1)),
        ]
        let results = ImageScanner.results(from: detections, allowed: [.qr], date: referenceDate)
        #expect(results.map(\.string) == ["large", "small"])
        #expect(results.allSatisfy { $0.source == .image })
        let bounds = results.first?.bounds ?? .zero
        #expect(abs(bounds.minY - 0.4) < 0.0001)
    }

    @Test func qrCodeImageIsGenerated() throws {
        let image = try #require(QRCodeImage.make("https://example.com", scale: 4))
        #expect(image.width == image.height)
        #expect(image.width >= 21 * 4)
    }
}
