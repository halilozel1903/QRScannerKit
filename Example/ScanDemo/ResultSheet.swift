@preconcurrency import NetworkExtension
import QRScannerKit
import SwiftUI
import UIKit

/// Shows what a scanned code means, with the action that fits: join a Wi-Fi network, open a
/// link, call, write a message or show a place.
struct ResultSheet: View {
    let result: ScanResult

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showsPassword = false
    @State private var status: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    DetailCard(rows: rows, showsPassword: $showsPassword)
                    actions
                    if let status {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Text("Read from a \(result.symbology.name)")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(result.payload.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(ScanTheme.accent)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: result.payload.kind.systemImage)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(ScanTheme.color(for: result.payload.kind), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(result.payload.kind.title.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(result.payload.summary)
                    .font(.title2.bold())
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Details

    private var rows: [DetailRow] {
        switch result.payload {
        case .wifi(let network):
            var rows = [
                DetailRow(label: "Network", value: network.ssid),
                DetailRow(label: "Security", value: network.security.name),
            ]
            if let password = network.password {
                rows.append(DetailRow(label: "Password", value: password, isSecret: true))
            }
            rows.append(DetailRow(label: "Hidden", value: network.isHidden ? "Yes" : "No"))
            return rows
        case .url(let url):
            return [DetailRow(label: "Address", value: url.absoluteString)]
        case .contact(let contact):
            var rows: [DetailRow] = []
            if let name = contact.name { rows.append(DetailRow(label: "Name", value: name)) }
            if let organization = contact.organization { rows.append(DetailRow(label: "Company", value: organization)) }
            if let title = contact.jobTitle { rows.append(DetailRow(label: "Title", value: title)) }
            rows += contact.phoneNumbers.map { DetailRow(label: "Phone", value: $0) }
            rows += contact.emails.map { DetailRow(label: "Email", value: $0) }
            rows += contact.urls.map { DetailRow(label: "Website", value: $0) }
            if let address = contact.address { rows.append(DetailRow(label: "Address", value: address)) }
            if let note = contact.note { rows.append(DetailRow(label: "Note", value: note)) }
            return rows
        case .location(let location):
            var rows = [DetailRow(label: "Coordinate", value: location.coordinateText)]
            if let query = location.query { rows.insert(DetailRow(label: "Place", value: query), at: 0) }
            return rows
        case .email(let email):
            var rows = [DetailRow(label: "To", value: email.address)]
            if let subject = email.subject { rows.append(DetailRow(label: "Subject", value: subject)) }
            if let body = email.body { rows.append(DetailRow(label: "Message", value: body)) }
            return rows
        case .phone(let number):
            return [DetailRow(label: "Number", value: number)]
        case .sms(let sms):
            var rows = [DetailRow(label: "To", value: sms.number)]
            if let body = sms.body { rows.append(DetailRow(label: "Message", value: body)) }
            return rows
        case .text(let text):
            return [DetailRow(label: "Text", value: text)]
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 10) {
            switch result.payload {
            case .wifi(let network):
                primaryButton("Join Network", systemImage: "wifi") { join(network) }
                if let password = network.password {
                    secondaryButton("Copy Password", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = password
                        status = "Password copied."
                    }
                }
            case .url, .email, .phone, .sms, .location:
                if let url = result.payload.actionURL {
                    primaryButton(primaryTitle, systemImage: result.payload.kind.systemImage) { openURL(url) }
                }
                secondaryButton("Copy", systemImage: "doc.on.doc") { copy() }
            case .contact, .text:
                secondaryButton("Copy", systemImage: "doc.on.doc") { copy() }
                ShareLink(item: result.string) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private var primaryTitle: String {
        switch result.payload.kind {
        case .url: "Open Link"
        case .email: "Write Email"
        case .phone: "Call"
        case .sms: "Send Message"
        case .location: "Open in Maps"
        default: "Open"
        }
    }

    private func primaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func secondaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func copy() {
        UIPasteboard.general.string = result.string
        status = "Copied."
    }

    /// Joins the network with NEHotspotConfiguration. On a device this needs the Hotspot
    /// Configuration capability; without it the password is copied instead.
    private func join(_ network: WiFiNetwork) {
        let configuration: NEHotspotConfiguration = switch network.security {
        case .open: NEHotspotConfiguration(ssid: network.ssid)
        case .wep: NEHotspotConfiguration(ssid: network.ssid, passphrase: network.password ?? "", isWEP: true)
        case .wpa, .wpa3: NEHotspotConfiguration(ssid: network.ssid, passphrase: network.password ?? "", isWEP: false)
        }
        configuration.hidden = network.isHidden
        status = "Joining \(network.ssid)…"
        Task {
            do {
                try await NEHotspotConfigurationManager.shared.apply(configuration)
                status = "Joined \(network.ssid)."
            } catch {
                if let password = network.password {
                    UIPasteboard.general.string = password
                    status = "Couldn't join automatically. The password is copied; paste it in Settings › Wi-Fi."
                } else {
                    status = "Couldn't join automatically. Choose \(network.ssid) in Settings › Wi-Fi."
                }
            }
        }
    }
}

struct DetailRow: Identifiable {
    let label: String
    let value: String
    var isSecret = false

    var id: String { label + value }
}

/// Label and value rows in a rounded card.
struct DetailCard: View {
    let rows: [DetailRow]
    @Binding var showsPassword: Bool

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.label)
                        .foregroundStyle(.secondary)
                        .frame(width: 92, alignment: .leading)
                    Group {
                        if row.isSecret, !showsPassword {
                            Text(String(repeating: "•", count: max(8, row.value.count)))
                        } else {
                            Text(row.value)
                                .textSelection(.enabled)
                        }
                    }
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if row.isSecret {
                        Button {
                            showsPassword.toggle()
                        } label: {
                            Image(systemName: showsPassword ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(showsPassword ? "Hide Password" : "Show Password")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                if index < rows.count - 1 {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
