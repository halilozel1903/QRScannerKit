import QRScannerKit
import SwiftUI

/// Scan's home screen: a big scan button, scanning from a photo and the history of this session.
struct ContentView: View {
    let history: ScanHistory

    @State private var isScanning = false
    @State private var selection: ScanResult?
    @State private var showsNoCodeAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScanHero(
                        onScan: { isScanning = true },
                        onPhotoResult: show,
                        onNoCode: { showsNoCodeAlert = true }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("History") {
                    if history.results.isEmpty {
                        ContentUnavailableView(
                            "No Scans Yet",
                            systemImage: "qrcode.viewfinder",
                            description: Text("Codes you scan show up here.")
                        )
                    } else {
                        ForEach(history.results) { result in
                            Button {
                                selection = result
                            } label: {
                                HistoryRow(result: result)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { history.remove(atOffsets: $0) }
                    }
                }
            }
            .navigationTitle("Scan")
        }
        .tint(ScanTheme.accent)
        .qrScanner(
            isPresented: $isScanning,
            configuration: ScannerConfiguration(symbologies: Symbology.all)
        ) { result in
            show(result)
        }
        .sheet(item: $selection) { result in
            ResultSheet(result: result)
                .presentationDetents([.medium, .large])
        }
        .alert("No Code Found", isPresented: $showsNoCodeAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The photo doesn't contain a QR code or barcode that can be read.")
        }
    }

    private func show(_ result: ScanResult) {
        history.add(result)
        selection = result
    }
}

/// The scan button card at the top of the home screen.
struct ScanHero: View {
    let onScan: () -> Void
    let onPhotoResult: (ScanResult) -> Void
    let onNoCode: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Button(action: onScan) {
                VStack(spacing: 14) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 54, weight: .medium))
                    Text("Scan a Code")
                        .font(.title3.bold())
                    Text("QR codes, barcodes, Wi-Fi, contacts and links")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(ScanTheme.gradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .buttonStyle(.plain)

            PhotoScanButton(onNoCode: onNoCode, onResult: onPhotoResult) {
                Label("Scan from Photo", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(ScanTheme.accent)
        }
        .padding(.vertical, 8)
    }
}

/// One scan in the history list.
struct HistoryRow: View {
    let result: ScanResult

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: result.payload.kind.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(ScanTheme.color(for: result.payload.kind), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(result.payload.summary)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text("\(result.payload.kind.title) · \(result.symbology.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(result.date, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

enum ScanTheme {
    static let accent = Color(red: 0.16, green: 0.42, blue: 1.0)

    static let gradient = LinearGradient(
        colors: [Color(red: 0.16, green: 0.42, blue: 1.0), Color(red: 0.05, green: 0.72, blue: 0.78)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func color(for kind: ScanPayload.Kind) -> Color {
        switch kind {
        case .url: .blue
        case .wifi: Color(red: 0.05, green: 0.62, blue: 0.68)
        case .contact: .orange
        case .location: .red
        case .email: .indigo
        case .phone, .sms: .green
        case .text: .gray
        }
    }
}
