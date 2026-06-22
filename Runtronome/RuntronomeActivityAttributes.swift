import ActivityKit

struct RuntronomeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var spm: Int
        var alertFrequency: String
        var phaseLabel: String
    }

    let trainingTitle: String
    let isGarminConnected: Bool
}
