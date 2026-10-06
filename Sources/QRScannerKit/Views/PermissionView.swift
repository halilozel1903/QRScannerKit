#if os(iOS)
import SwiftUI

/// What the scanner shows instead of the camera when it cannot use it.
struct PermissionView: View {
    let permission: CameraPermission
    let showsPhotoPicker: Bool
    let symbologies: Set<Symbology>
    let onRequestAccess: () -> Void
    let onOpenSettings: () -> Void
    let onPhotoResult: (ScanResult) -> Void
    let onNoCode: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .scannerGlass(in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.bold())
                Text(message)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.78))
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)

            VStack(spacing: 12) {
                switch permission {
                case .notDetermined:
                    Button(action: onRequestAccess) {
                        Text("Allow Camera Access")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .scannerProminentButtonStyle()
                case .denied:
                    Button(action: onOpenSettings) {
                        Text("Open Settings")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .scannerProminentButtonStyle()
                case .authorized, .restricted, .unsupported:
                    EmptyView()
                }

                if showsPhotoPicker {
                    PhotoScanButton(symbologies: symbologies, onNoCode: onNoCode, onResult: onPhotoResult) {
                        Label("Scan a Photo Instead", systemImage: "photo.on.rectangle")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .scannerButtonStyle()
                    .tint(.white)
                }
            }
            .padding(.top, 8)
        }
        .padding(28)
        .frame(maxWidth: 420)
    }

    private var systemImage: String {
        switch permission {
        case .notDetermined, .authorized: "camera.fill"
        case .denied: "video.slash.fill"
        case .restricted: "lock.fill"
        case .unsupported: "camera.metering.unknown"
        }
    }

    private var title: String {
        switch permission {
        case .notDetermined, .authorized: "Scan with Your Camera"
        case .denied: "Camera Access Is Off"
        case .restricted: "Camera Is Restricted"
        case .unsupported: "No Camera Available"
        }
    }

    private var message: String {
        switch permission {
        case .notDetermined, .authorized:
            "Allow camera access to scan QR codes and barcodes. The picture is only used to read codes."
        case .denied:
            "Turn on Camera for this app in Settings to scan QR codes and barcodes."
        case .restricted:
            "Camera access is limited by Screen Time or by your organization."
        case .unsupported:
            "This device has no camera that can read codes. You can still scan a code from a photo."
        }
    }
}
#endif
