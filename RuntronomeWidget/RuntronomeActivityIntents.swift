import AppIntents
import ActivityKit

struct IncreaseSPMIntent: AppIntent {
    static let title: LocalizedStringResource = "Increase SPM"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        await applyDelta(5)
        return .result()
    }
}

struct DecreaseSPMIntent: AppIntent {
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
    for activity in Activity<RuntronomeActivityAttributes>.activities {
        let newState = RuntronomeActivityAttributes.ContentState(
            spm: newSPM,
            alertFrequency: activity.content.state.alertFrequency,
            phaseLabel: activity.content.state.phaseLabel
        )
        await activity.update(.init(state: newState, staleDate: nil))
    }
}
