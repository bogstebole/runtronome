import Foundation
import WidgetKit

enum SharedStore {
    private static let defaults = UserDefaults(suiteName: "group.com.bogste.runtronome")!

    static func sync(spm: Int, alertFrequency: String, phaseLabel: String, isGarminConnected: Bool) {
        defaults.set(spm, forKey: "spm")
        defaults.set(alertFrequency, forKey: "alertFrequency")
        defaults.set(phaseLabel, forKey: "phaseLabel")
        defaults.set(isGarminConnected, forKey: "isGarminConnected")
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func readSPM() -> Int {
        defaults.integer(forKey: "spm").nonZero ?? 175
    }

    static func read() -> (spm: Int, alertFrequency: String, phaseLabel: String, isGarminConnected: Bool) {
        (
            spm: defaults.integer(forKey: "spm").nonZero ?? 175,
            alertFrequency: defaults.string(forKey: "alertFrequency") ?? "EVERY OTHER",
            phaseLabel: defaults.string(forKey: "phaseLabel") ?? "",
            isGarminConnected: defaults.bool(forKey: "isGarminConnected")
        )
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
