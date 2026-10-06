#if os(iOS)
import SwiftUI

extension View {
    /// Liquid Glass on iOS 26, a dark material before.
    @ViewBuilder
    func scannerGlass(in shape: some Shape) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
                .environment(\.colorScheme, .dark)
        }
    }

    /// `.glassProminent` on iOS 26, `.borderedProminent` before.
    @ViewBuilder
    func scannerProminentButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

    /// `.glass` on iOS 26, `.bordered` before.
    @ViewBuilder
    func scannerButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }
}

/// A round icon button on the camera picture.
struct ScannerIconButton: View {
    let title: String
    let systemImage: String
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ScannerIconLabel(title: title, systemImage: systemImage, isActive: isActive)
        }
        .buttonStyle(.plain)
    }
}

/// The look of `ScannerIconButton`, shared with the photo picker.
struct ScannerIconLabel: View {
    let title: String
    let systemImage: String
    var isActive = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(isActive ? Color.black : Color.white)
            .frame(width: 48, height: 48)
            .background {
                if isActive {
                    Circle().fill(Color.yellow)
                }
            }
            .scannerGlass(in: Circle())
            .contentShape(Circle())
            .accessibilityLabel(title)
    }
}
#endif
