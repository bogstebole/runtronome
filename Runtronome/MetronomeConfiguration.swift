import Foundation

/// The slice of state the sync flow hands to the metronome screen. Keeping it in
/// one value type means `ContentView` has a single, testable entry point and the
/// existing default behaviour is preserved via `.default`.
struct MetronomeConfiguration {
    var trainingTitle: String
    var phaseLabel: String
    var startingSPM: Int
    var isGarminConnected: Bool
    /// Full plan retained so phases could later drive the metronome automatically.
    var plan: WorkoutPlan?

    init(
        trainingTitle: String,
        phaseLabel: String,
        startingSPM: Int,
        isGarminConnected: Bool,
        plan: WorkoutPlan?
    ) {
        self.trainingTitle = trainingTitle
        self.phaseLabel = phaseLabel
        self.startingSPM = startingSPM
        self.isGarminConnected = isGarminConnected
        self.plan = plan
    }

    /// Seeds the metronome from a configured plan: title + the first assigned
    /// phase (falling back to the first phase) become the starting cadence.
    init(plan: WorkoutPlan) {
        let lead = plan.phases.first(where: \.isAssigned) ?? plan.phases.first
        self.init(
            trainingTitle: plan.title,
            phaseLabel: lead?.title.uppercased() ?? "",
            startingSPM: lead?.targetSPM ?? 175,
            isGarminConnected: true,
            plan: plan
        )
    }

    /// The app's original hardcoded state — used by previews and the default path.
    static let `default` = MetronomeConfiguration(
        trainingTitle: "Goal Pace Repeats",
        phaseLabel: "WARM UP",
        startingSPM: 175,
        isGarminConnected: true,
        plan: nil
    )
}
