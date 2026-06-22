import AppIntents
import Foundation

struct IncreaseSPMIntent: AppIntent {
    static let title: LocalizedStringResource = "Increase SPM"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        applyDelta(5)
        return .result()
    }
}

struct DecreaseSPMIntent: AppIntent {
    static let title: LocalizedStringResource = "Decrease SPM"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        applyDelta(-5)
        return .result()
    }
}

private func applyDelta(_ delta: Int) {
    let defaults = UserDefaults(suiteName: "group.com.bogste.runtronome")!
    let current = max(1, defaults.integer(forKey: "spm"))
    defaults.set(max(30, min(300, current + delta)), forKey: "spm")
}
