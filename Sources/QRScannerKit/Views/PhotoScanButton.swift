#if os(iOS)
import PhotosUI
import SwiftUI

/// Picks a photo from the library and reads the first code in it with Vision.
///
/// ```swift
/// PhotoScanButton { result in
///     open(result.payload)
/// }
/// ```
public struct PhotoScanButton<Label: View>: View {
    private let symbologies: Set<Symbology>
    private let onNoCode: (() -> Void)?
    private let onResult: (ScanResult) -> Void
    private let label: Label

    @State private var item: PhotosPickerItem?
    @State private var isScanning = false

    /// - Parameters:
    ///   - symbologies: The codes to look for. All symbologies by default.
    ///   - onNoCode: Called when the photo has no readable code.
    ///   - onResult: Called with the largest code in the photo.
    ///   - label: The button's label.
    public init(
        symbologies: Set<Symbology> = Symbology.all,
        onNoCode: (() -> Void)? = nil,
        onResult: @escaping (ScanResult) -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.symbologies = symbologies
        self.onNoCode = onNoCode
        self.onResult = onResult
        self.label = label()
    }

    public var body: some View {
        PhotosPicker(selection: $item, matching: .images) {
            label
        }
        .disabled(isScanning)
        .onChange(of: item) {
            guard let picked = item else { return }
            item = nil
            isScanning = true
            Task {
                let data = try? await picked.loadTransferable(type: Data.self)
                let results: [ScanResult]
                if let data {
                    results = (try? await ImageScanner.scan(imageData: data, symbologies: symbologies)) ?? []
                } else {
                    results = []
                }
                isScanning = false
                if let first = results.first {
                    onResult(first)
                } else {
                    onNoCode?()
                }
            }
        }
    }
}

extension PhotoScanButton where Label == SwiftUI.Label<Text, Image> {
    /// A button titled "Scan from Photo" with a photo icon.
    public init(
        _ title: String = "Scan from Photo",
        symbologies: Set<Symbology> = Symbology.all,
        onNoCode: (() -> Void)? = nil,
        onResult: @escaping (ScanResult) -> Void
    ) {
        self.init(symbologies: symbologies, onNoCode: onNoCode, onResult: onResult) {
            SwiftUI.Label(title, systemImage: "photo.on.rectangle")
        }
    }
}
#endif
