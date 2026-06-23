import SwiftUI

@main
struct RuntronomeApp: App {
    init() {
        MomoTrustFont.register()
    }

    var body: some Scene {
        WindowGroup {
            // Metronome is the home screen. The manual plan builder is reached
            // from its top-right icon. RootFlowView (Garmin/Health sync) is kept
            // for later and intentionally not wired into launch yet.
            ContentView()
        }
    }
}
