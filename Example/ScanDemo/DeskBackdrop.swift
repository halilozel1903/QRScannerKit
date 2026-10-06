import QRScannerKit
import UIKit

/// Draws a café table seen from above, with a printed "Free Wi-Fi" card whose QR code sits right
/// inside the viewfinder. The screenshot scenes show it where the camera picture would be, since
/// the simulator has no camera.
@MainActor
enum DeskBackdrop {
    static let wifiPayload = "WIFI:T:WPA;S:Harbor Café Guest;P:flatwhite2026;;"

    /// Renders the table for a screen of `size` points, with the QR code centered on `viewfinder`.
    static func render(size: CGSize, viewfinder: CGRect, payload: String = wifiPayload) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cg = context.cgContext
            drawTable(in: CGRect(origin: .zero, size: size), cg: cg)
            drawNotebook(size: size, cg: cg)
            drawPen(size: size, cg: cg)
            drawCup(size: size, cg: cg)
            drawCard(viewfinder: viewfinder, payload: payload, cg: cg)
            drawVignette(in: CGRect(origin: .zero, size: size), cg: cg)
        }
    }

    // MARK: - Table

    private static func drawTable(in rect: CGRect, cg: CGContext) {
        let colors = [
            UIColor(red: 0.55, green: 0.36, blue: 0.24, alpha: 1).cgColor,
            UIColor(red: 0.43, green: 0.27, blue: 0.17, alpha: 1).cgColor,
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            cg.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
        }

        // Planks with slightly different tones.
        let plankWidth = max(rect.width / 3.2, 120)
        var random = SeededRandom(seed: 7)
        var x = rect.minX - plankWidth * 0.35
        while x < rect.maxX {
            let tone = CGFloat(random.next()) * 0.08
            cg.setFillColor(UIColor(white: tone > 0.04 ? 1 : 0, alpha: abs(tone - 0.04)).cgColor)
            cg.fill(CGRect(x: x, y: rect.minY, width: plankWidth, height: rect.height))
            cg.setFillColor(UIColor(red: 0.22, green: 0.13, blue: 0.08, alpha: 0.55).cgColor)
            cg.fill(CGRect(x: x + plankWidth - 1.5, y: rect.minY, width: 1.5, height: rect.height))
            x += plankWidth
        }

        // Grain: long, gently waving lines.
        cg.setLineWidth(1)
        for _ in 0..<Int(rect.width / 5) {
            let startX = rect.minX + CGFloat(random.next()) * rect.width
            let amplitude = 2 + CGFloat(random.next()) * 6
            let alpha = 0.04 + CGFloat(random.next()) * 0.08
            cg.setStrokeColor(UIColor(red: 0.2, green: 0.11, blue: 0.06, alpha: alpha).cgColor)
            cg.move(to: CGPoint(x: startX, y: rect.minY))
            var y = rect.minY
            while y < rect.maxY {
                y += 24
                cg.addLine(to: CGPoint(x: startX + sin(y / 90 + startX) * amplitude, y: y))
            }
            cg.strokePath()
        }
    }

    private static func drawVignette(in rect: CGRect, cg: CGContext) {
        let colors = [UIColor.black.withAlphaComponent(0).cgColor, UIColor.black.withAlphaComponent(0.45).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.55, 1]) else { return }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        cg.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: hypot(rect.width, rect.height) / 2, options: [.drawsAfterEndLocation])
    }

    // MARK: - Objects

    private static func withShadow(_ cg: CGContext, blur: CGFloat = 18, offset: CGSize = CGSize(width: 0, height: 10), _ draw: () -> Void) {
        cg.saveGState()
        cg.setShadow(offset: offset, blur: blur, color: UIColor.black.withAlphaComponent(0.45).cgColor)
        draw()
        cg.restoreGState()
    }

    private static func drawNotebook(size: CGSize, cg: CGContext) {
        let unit = min(size.width, size.height)
        cg.saveGState()
        cg.translateBy(x: size.width * 0.08, y: size.height * 0.1)
        cg.rotate(by: -0.32)
        let page = CGRect(x: -unit * 0.35, y: -unit * 0.3, width: unit * 0.62, height: unit * 0.8)
        withShadow(cg) {
            cg.setFillColor(UIColor(red: 0.98, green: 0.96, blue: 0.9, alpha: 1).cgColor)
            cg.addPath(UIBezierPath(roundedRect: page, cornerRadius: 10).cgPath)
            cg.fillPath()
        }
        cg.setStrokeColor(UIColor(red: 0.55, green: 0.7, blue: 0.9, alpha: 0.7).cgColor)
        cg.setLineWidth(1)
        var y = page.minY + 30
        while y < page.maxY - 12 {
            cg.move(to: CGPoint(x: page.minX + 10, y: y))
            cg.addLine(to: CGPoint(x: page.maxX - 10, y: y))
            y += 18
        }
        cg.strokePath()
        cg.setStrokeColor(UIColor(red: 0.9, green: 0.45, blue: 0.45, alpha: 0.7).cgColor)
        cg.move(to: CGPoint(x: page.minX + 34, y: page.minY))
        cg.addLine(to: CGPoint(x: page.minX + 34, y: page.maxY))
        cg.strokePath()
        cg.restoreGState()
    }

    private static func drawPen(size: CGSize, cg: CGContext) {
        let unit = min(size.width, size.height)
        cg.saveGState()
        cg.translateBy(x: size.width * 0.86, y: size.height * 0.2)
        cg.rotate(by: 0.5)
        let body = CGRect(x: -unit * 0.022, y: -unit * 0.3, width: unit * 0.044, height: unit * 0.52)
        withShadow(cg, blur: 10, offset: CGSize(width: 0, height: 6)) {
            cg.setFillColor(UIColor(red: 0.12, green: 0.16, blue: 0.3, alpha: 1).cgColor)
            cg.addPath(UIBezierPath(roundedRect: body, cornerRadius: body.width / 2).cgPath)
            cg.fillPath()
        }
        cg.setFillColor(UIColor(white: 0.85, alpha: 1).cgColor)
        cg.fill(CGRect(x: body.minX, y: body.minY + body.height * 0.18, width: body.width, height: body.height * 0.03))
        cg.restoreGState()
    }

    private static func drawCup(size: CGSize, cg: CGContext) {
        let unit = min(size.width, size.height)
        let center = CGPoint(x: size.width * 0.84, y: size.height * 0.86)
        let saucer = unit * 0.3
        withShadow(cg) {
            cg.setFillColor(UIColor(white: 0.96, alpha: 1).cgColor)
            cg.fillEllipse(in: CGRect(x: center.x - saucer, y: center.y - saucer, width: saucer * 2, height: saucer * 2))
        }
        // Handle
        cg.setFillColor(UIColor(white: 0.93, alpha: 1).cgColor)
        cg.fill(CGRect(x: center.x - saucer * 0.95, y: center.y - unit * 0.025, width: saucer * 0.4, height: unit * 0.05))
        // Cup and coffee
        let cup = saucer * 0.68
        withShadow(cg, blur: 8, offset: CGSize(width: 0, height: 4)) {
            cg.setFillColor(UIColor.white.cgColor)
            cg.fillEllipse(in: CGRect(x: center.x - cup, y: center.y - cup, width: cup * 2, height: cup * 2))
        }
        let coffee = cup * 0.82
        let colors = [
            UIColor(red: 0.78, green: 0.58, blue: 0.38, alpha: 1).cgColor,
            UIColor(red: 0.42, green: 0.25, blue: 0.14, alpha: 1).cgColor,
        ] as CFArray
        cg.saveGState()
        cg.addEllipse(in: CGRect(x: center.x - coffee, y: center.y - coffee, width: coffee * 2, height: coffee * 2))
        cg.clip()
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            cg.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: coffee, options: [])
        }
        // Latte art heart
        cg.setFillColor(UIColor(red: 0.96, green: 0.9, blue: 0.8, alpha: 0.9).cgColor)
        let heart = coffee * 0.45
        cg.fillEllipse(in: CGRect(x: center.x - heart, y: center.y - heart * 0.75, width: heart, height: heart))
        cg.fillEllipse(in: CGRect(x: center.x, y: center.y - heart * 0.75, width: heart, height: heart))
        cg.move(to: CGPoint(x: center.x - heart * 0.97, y: center.y - heart * 0.1))
        cg.addLine(to: CGPoint(x: center.x + heart * 0.97, y: center.y - heart * 0.1))
        cg.addLine(to: CGPoint(x: center.x, y: center.y + heart * 0.9))
        cg.closePath()
        cg.fillPath()
        cg.restoreGState()
    }

    /// The printed card. The QR code is centered on the viewfinder and fills about 70% of it.
    private static func drawCard(viewfinder: CGRect, payload: String, cg: CGContext) {
        let side = viewfinder.width * 0.68
        let padding = side * 0.12
        let titleHeight = side * 0.3
        let footerHeight = side * 0.26
        let card = CGRect(
            x: -side / 2 - padding,
            y: -side / 2 - padding - titleHeight,
            width: side + padding * 2,
            height: side + padding * 2 + titleHeight + footerHeight
        )

        cg.saveGState()
        cg.translateBy(x: viewfinder.midX, y: viewfinder.midY)
        cg.rotate(by: -0.035)

        withShadow(cg, blur: 22, offset: CGSize(width: 0, height: 14)) {
            cg.setFillColor(UIColor(white: 0.99, alpha: 1).cgColor)
            cg.addPath(UIBezierPath(roundedRect: card, cornerRadius: side * 0.07).cgPath)
            cg.fillPath()
        }

        // Header band
        let band = CGRect(x: card.minX, y: card.minY, width: card.width, height: titleHeight + padding * 0.6)
        cg.saveGState()
        cg.addPath(UIBezierPath(roundedRect: band, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: side * 0.07, height: side * 0.07)).cgPath)
        cg.clip()
        cg.setFillColor(UIColor(red: 0.09, green: 0.33, blue: 0.36, alpha: 1).cgColor)
        cg.fill(band)
        cg.restoreGState()

        let title = NSAttributedString(string: "Harbor Café", attributes: [
            .font: UIFont.systemFont(ofSize: side * 0.12, weight: .bold),
            .foregroundColor: UIColor.white,
        ])
        let subtitle = NSAttributedString(string: "FREE WI-FI", attributes: [
            .font: UIFont.systemFont(ofSize: side * 0.065, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.8),
            .kern: side * 0.012,
        ])
        drawCentered(title, at: CGPoint(x: 0, y: band.minY + band.height * 0.38))
        drawCentered(subtitle, at: CGPoint(x: 0, y: band.minY + band.height * 0.74))

        if let code = QRCodeImage.make(payload, scale: 12, correction: .medium) {
            cg.interpolationQuality = .none
            UIImage(cgImage: code).draw(in: CGRect(x: -side / 2, y: -side / 2, width: side, height: side))
        }

        let footer = NSAttributedString(string: "Scan to join · Ask us for the password", attributes: [
            .font: UIFont.systemFont(ofSize: side * 0.058, weight: .medium),
            .foregroundColor: UIColor(white: 0.35, alpha: 1),
        ])
        drawCentered(footer, at: CGPoint(x: 0, y: side / 2 + padding + footerHeight * 0.35))

        cg.restoreGState()
    }

    private static func drawCentered(_ text: NSAttributedString, at center: CGPoint) {
        let size = text.size()
        text.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
    }
}

/// A tiny deterministic random generator, so every capture draws the same table.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 6_364_136_223_846_793_005 &+ 1
    }

    /// A value in 0..<1.
    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(UInt64(1) << 53)
    }
}
