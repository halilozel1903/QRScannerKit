/// Whether the scanner can use the camera.
public enum CameraPermission: String, Hashable, Sendable, CaseIterable {
    /// The user has not been asked yet.
    case notDetermined
    /// Camera access is allowed.
    case authorized
    /// The user turned camera access off. It can be turned on again in Settings.
    case denied
    /// Camera access is blocked by Screen Time or a device management profile.
    case restricted
    /// The device has no camera that can scan codes (for example the simulator).
    case unsupported

    /// `true` when the camera can run.
    public var canScan: Bool { self == .authorized }

    /// `true` when the user can change the answer in the Settings app.
    public var canOpenSettings: Bool { self == .denied }
}
