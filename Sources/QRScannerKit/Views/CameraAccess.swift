#if os(iOS)
import AVFoundation
import UIKit

extension CameraPermission {
    /// The camera permission right now. `.unsupported` when the device has no camera.
    @MainActor
    public static var current: CameraPermission {
        CameraAccess.permission
    }

    /// Shows the system prompt when the user has not been asked yet, then returns the answer.
    @MainActor
    public static func request() async -> CameraPermission {
        await CameraAccess.requestAccess()
    }
}

/// Camera checks shared by the scanners: permission, torch and the Settings shortcut.
@MainActor
enum CameraAccess {
    static var device: AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
    }

    static var permission: CameraPermission {
        guard device != nil else { return .unsupported }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        @unknown default: return .denied
        }
    }

    static func requestAccess() async -> CameraPermission {
        guard device != nil else { return .unsupported }
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        return permission
    }

    static var isTorchAvailable: Bool {
        device?.hasTorch ?? false
    }

    /// Turns the torch on or off. Works while VisionKit's data scanner runs, which has no torch
    /// API of its own.
    static func setTorch(_ isOn: Bool) {
        guard let device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = isOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            // The camera is busy or gone; the button simply has no effect.
        }
    }

    /// Opens this app's page in the Settings app.
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
#endif
