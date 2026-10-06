#if os(iOS)
import SwiftUI

/// Dims everything outside the viewfinder and draws its four corners, which breathe gently while
/// scanning and turn green when a code was read.
struct ViewfinderOverlay: View {
    let size: CGSize
    let rect: CGRect
    let isSuccess: Bool
    let prompt: String?

    @State private var isBreathing = false
    @State private var isSweeping = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var cornerRadius: CGFloat { min(28, rect.width / 8) }

    var body: some View {
        ZStack {
            Path { path in
                path.addRect(CGRect(origin: .zero, size: size))
                path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius), style: .continuous)
            }
            .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))

            if !isSuccess, !reduceMotion, rect.height > 40 {
                LinearGradient(
                    colors: [.clear, Color.accentColor.opacity(0.9), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: rect.width - 32, height: 2)
                .shadow(color: Color.accentColor.opacity(0.8), radius: 6)
                .position(x: rect.midX, y: isSweeping ? rect.maxY - 18 : rect.minY + 18)
            }

            ViewfinderCorners(length: min(44, rect.width / 4), radius: cornerRadius)
                .stroke(
                    isSuccess ? Color.green : Color.white,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                )
                .frame(width: rect.width, height: rect.height)
                .scaleEffect(isSuccess ? 0.94 : (isBreathing ? 1.02 : 0.98))
                .shadow(color: .black.opacity(0.35), radius: 8)
                .position(x: rect.midX, y: rect.midY)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSuccess)

            if isSuccess {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .green)
                    .shadow(radius: 8)
                    .position(x: rect.midX, y: rect.midY)
                    .transition(.scale.combined(with: .opacity))
            }

            if let prompt {
                Text(prompt)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .scannerGlass(in: Capsule())
                    .frame(maxWidth: size.width - 48)
                    .position(x: rect.midX, y: min(rect.maxY + 44, size.height - 120))
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(.easeOut(duration: 0.2), value: isSuccess)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(prompt ?? "Viewfinder")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isSweeping = true
            }
        }
    }
}

/// The four rounded corner brackets of a viewfinder.
public struct ViewfinderCorners: Shape {
    /// The length of each bracket arm.
    public var length: CGFloat
    /// The corner radius.
    public var radius: CGFloat

    public init(length: CGFloat = 40, radius: CGFloat = 24) {
        self.length = length
        self.radius = radius
    }

    public func path(in rect: CGRect) -> Path {
        let arm = max(0, min(length, rect.width / 2, rect.height / 2))
        let r = max(0, min(radius, arm))
        var path = Path()

        // Top left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + r, y: rect.minY), radius: r)
        path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))

        // Top right
        path.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + r), radius: r)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))

        // Bottom right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - r, y: rect.maxY), radius: r)
        path.addLine(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))

        // Bottom left
        path.move(to: CGPoint(x: rect.minX + arm, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - r), radius: r)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - arm))

        return path
    }
}
#endif
