import CoreGraphics

/// Where the viewfinder sits on screen, and how big it is.
///
/// The scanner draws the viewfinder at `rect(in:)` and only reads codes inside it.
public struct ViewfinderLayout: Hashable, Sendable {
    /// Width divided by height. `1` for QR codes, about `1.8` for product barcodes.
    public var aspectRatio: CGFloat
    /// The share of the view's width the viewfinder may use.
    public var widthFraction: CGFloat
    /// The largest width in points, so it stays a sensible size on iPad.
    public var maxWidth: CGFloat
    /// The vertical position of the viewfinder's center as a share of the view's height.
    public var verticalCenter: CGFloat

    public init(aspectRatio: CGFloat = 1, widthFraction: CGFloat = 0.7, maxWidth: CGFloat = 320, verticalCenter: CGFloat = 0.45) {
        self.aspectRatio = aspectRatio
        self.widthFraction = widthFraction
        self.maxWidth = maxWidth
        self.verticalCenter = verticalCenter
    }

    /// A square viewfinder for QR, Aztec and Data Matrix codes.
    public static let square = ViewfinderLayout()

    /// A wide viewfinder for EAN, UPC and other one-dimensional barcodes.
    public static let wide = ViewfinderLayout(aspectRatio: 1.8, widthFraction: 0.82, maxWidth: 420)

    /// The viewfinder in view coordinates. It never leaves the view and is never taller than 70%
    /// of it.
    public func rect(in size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        let ratio = aspectRatio > 0 ? aspectRatio : 1
        var width = min(size.width * min(max(widthFraction, 0), 1), maxWidth)
        var height = width / ratio
        let maxHeight = size.height * 0.7
        if height > maxHeight {
            height = maxHeight
            width = height * ratio
        }
        let centerY = size.height * min(max(verticalCenter, 0), 1)
        let y = min(max(centerY - height / 2, 0), size.height - height)
        return CGRect(x: (size.width - width) / 2, y: y, width: width, height: height)
    }
}

/// Region-of-interest math: from a viewfinder in view coordinates to the normalized rectangles
/// the scanners use.
public enum RegionOfInterest {
    /// `rect` as a share of `size` (0...1, origin at the top left), clipped to the view.
    public static func normalized(_ rect: CGRect, in size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        let clipped = rect.intersection(CGRect(origin: .zero, size: size))
        guard !clipped.isNull, !clipped.isEmpty else { return .zero }
        return CGRect(
            x: clipped.minX / size.width,
            y: clipped.minY / size.height,
            width: clipped.width / size.width,
            height: clipped.height / size.height
        )
    }

    /// Converts a normalized rect back to view coordinates.
    public static func denormalized(_ rect: CGRect, in size: CGSize) -> CGRect {
        CGRect(x: rect.minX * size.width, y: rect.minY * size.height, width: rect.width * size.width, height: rect.height * size.height)
    }

    /// The part of a camera image that a normalized view rect covers when the image fills the
    /// view (aspect fill, centered, so the image's overflow is cropped).
    ///
    /// - Parameters:
    ///   - rect: A normalized rect in the view, origin at the top left.
    ///   - viewSize: The size of the view.
    ///   - imageSize: The size of the camera image, in the same orientation as the view.
    /// - Returns: A normalized rect in the image, origin at the top left, clipped to 0...1.
    public static func normalizedInImage(_ rect: CGRect, viewSize: CGSize, imageSize: CGSize) -> CGRect {
        guard viewSize.width > 0, viewSize.height > 0, imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let shown = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let offset = CGPoint(x: (shown.width - viewSize.width) / 2, y: (shown.height - viewSize.height) / 2)
        let inView = denormalized(rect, in: viewSize)
        let inShownImage = inView.offsetBy(dx: offset.x, dy: offset.y)
        return normalized(inShownImage, in: shown)
    }

    /// Flips a normalized rect between a top-left origin (UIKit, SwiftUI) and the bottom-left
    /// origin Vision uses. The conversion is its own inverse.
    public static func flipped(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: 1 - rect.maxY, width: rect.width, height: rect.height)
    }

    /// `true` when the center of `bounds` lies inside `region`. Both rects use the same space.
    public static func region(_ region: CGRect, contains bounds: CGRect) -> Bool {
        region.contains(CGPoint(x: bounds.midX, y: bounds.midY))
    }
}
