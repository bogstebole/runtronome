import ActivityKit
import AppIntents
import Foundation

// `LiveActivityIntent` (not a plain `AppIntent`) is what makes these run in the
// APP's process when tapped from the Live Activity. That matters because the
// activity was created by the app — only there does `Activity.activities`
// contain it and `activity.update(...)` actually redraw the widget. As a plain
// AppIntent the button ran in the widget extension process, where the update
// silently did nothing (the SPM value changed in shared storage, so the app
// picked it up, but the widget itself never refreshed).
//
// For this to dispatch into the app process, this file is a member of BOTH the
// widget extension target (to build the Button) and the app target (to execute).

struct IncreaseSPMIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Increase SPM"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        await applyDelta(5)
        return .result()
    }
}

struct DecreaseSPMIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Decrease SPM"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        await applyDelta(-5)
        return .result()
    }
}

private func applyDelta(_ delta: Int) async {
    let defaults = UserDefaults(suiteName: "group.com.bogste.runtronome")!
    let current = max(1, defaults.integer(forKey: "spm"))
    let newSPM = max(30, min(300, current + delta))
    defaults.set(newSPM, forKey: "spm")

    let state = RuntronomeActivityAttributes.ContentState(
        spm: newSPM,
        alertFrequency: defaults.string(forKey: "alertFrequency") ?? "EVERY OTHER",
        phaseLabel: defaults.string(forKey: "phaseLabel") ?? ""
    )
    for activity in Activity<RuntronomeActivityAttributes>.activities {
        await activity.update(.init(state: state, staleDate: nil))
    }
}
