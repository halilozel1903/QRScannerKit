import SwiftUI

@main
struct ScanDemoApp: App {
    @State private var history = ScanHistory()

    var body: some Scene {
        WindowGroup {
            if let scene = ScreenshotScene.current {
                // Screenshot scenes use a still "camera" picture and never touch the camera.
                ScreenshotView(scene: scene)
            } else {
                ContentView(history: history)
            }
        }
    }
}
