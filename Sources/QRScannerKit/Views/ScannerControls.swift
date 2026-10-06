#if os(iOS)
import SwiftUI

/// The buttons around the picture: close, photo and torch at the top, zoom at the bottom.
struct ScannerControls: View {
    let model: ScannerModel
    let configuration: ScannerConfiguration
    let onCancel: (() -> Void)?

    private var zoomOptions: [Double] {
        configuration.zoomFactors
            .filter { $0 >= 1 && $0 <= model.maxZoomFactor + 0.01 }
            .sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let onCancel {
                    ScannerIconButton(title: "Close", systemImage: "xmark", action: onCancel)
                }
                Spacer(minLength: 0)
                if configuration.showsPhotoPicker, model.permission.canScan {
                    PhotoScanButton(
                        symbologies: configuration.symbologies,
                        onNoCode: { model.show(notice: "No code found in this photo") },
                        onResult: { model.deliver($0) }
                    ) {
                        ScannerIconLabel(title: "Scan from Photo", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.plain)
                }
                if configuration.showsTorchButton, model.permission.canScan, model.isTorchAvailable {
                    ScannerIconButton(
                        title: model.isTorchOn ? "Turn Off Flashlight" : "Turn On Flashlight",
                        systemImage: model.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                        isActive: model.isTorchOn
                    ) {
                        model.toggleTorch()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer(minLength: 0)

            if let notice = model.notice {
                Text(notice)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .scannerGlass(in: Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 12)
            }

            if configuration.showsZoomControls, model.permission.canScan, zoomOptions.count > 1 {
                ZoomPicker(options: zoomOptions, selection: model.zoomFactor) { factor in
                    model.setZoom(factor)
                }
                .padding(.bottom, 16)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.notice)
    }
}

/// "1×  2×  4×" buttons in a capsule.
struct ZoomPicker: View {
    let options: [Double]
    let selection: Double
    let onSelect: (Double) -> Void

    private var selected: Double {
        options.min { abs($0 - selection) < abs($1 - selection) } ?? 1
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { factor in
                let isSelected = factor == selected
                Button {
                    onSelect(factor)
                } label: {
                    Text(Self.label(for: factor))
                        .font(.footnote.weight(.bold).monospacedDigit())
                        .foregroundStyle(isSelected ? Color.yellow : Color.white)
                        .frame(width: isSelected ? 44 : 36, height: isSelected ? 44 : 36)
                        .background(Circle().fill(Color.black.opacity(isSelected ? 0.45 : 0.25)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zoom \(Self.label(for: factor))")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(6)
        .scannerGlass(in: Capsule())
        .animation(.spring(response: 0.25), value: selected)
    }

    static func label(for factor: Double) -> String {
        factor.rounded() == factor ? "\(Int(factor))×" : String(format: "%.1f×", factor)
    }
}
#endif
