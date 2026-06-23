import Foundation

// MARK: - Workout Plan Models
//
// Pure value types describing a structured running workout (the shape Garmin
// Connect uses: a titled plan made of ordered steps/phases). These are the
// single source of truth shared by the fetcher service and the UI layer.

/// How a phase is measured. Garmin steps are time-based, distance-based, or
/// "open" (run until the user taps lap). Codable synthesis keeps the JSON tidy.
enum PhaseGoal: Codable, Equatable {
    case time(seconds: Int)
    case distance(meters: Int)
    case open

    /// Human-readable goal, e.g. "10 min", "800 m", "1.5 km", "Open".
    var display: String {
        switch self {
        case .time(let seconds):
            let minutes = seconds / 60
            let remainder = seconds % 60
            return remainder == 0 ? "\(minutes) min" : String(format: "%d:%02d", minutes, remainder)
        case .distance(let meters):
            if meters >= 1000 {
                return String(format: "%.1f km", Double(meters) / 1000)
            }
            return "\(meters) m"
        case .open:
            return "Open"
        }
    }
}

/// One segment of a run with a user-assignable cadence target.
struct WorkoutPhase: Identifiable, Codable, Equatable {
    let id: UUID
    /// Free-text phase name, e.g. "Warm up". `var` so the builder can edit it.
    var title: String
    var goal: PhaseGoal
    /// Target steps-per-minute for this phase. `nil` until the user assigns it.
    var targetSPM: Int?
    /// Optional per-phase description/instruction. Optional so mock/HealthKit
    /// payloads decode/build without it.
    var note: String?

    init(id: UUID = UUID(), title: String, goal: PhaseGoal, targetSPM: Int? = nil, note: String? = nil) {
        self.id = id
        self.title = title
        self.goal = goal
        self.targetSPM = targetSPM
        self.note = note
    }

    /// `true` once a usable cadence has been set.
    var isAssigned: Bool { (targetSPM ?? 0) > 0 }
}

/// A full day's structured workout.
struct WorkoutPlan: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let date: Date
    let location: String
    let temperature: String
    var phases: [WorkoutPhase]

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        location: String,
        temperature: String,
        phases: [WorkoutPhase]
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.location = location
        self.temperature = temperature
        self.phases = phases
    }

    /// Number of phases with a cadence already assigned.
    var assignedCount: Int { phases.filter(\.isAssigned).count }

    /// `true` when every phase has a target SPM.
    var allAssigned: Bool { !phases.isEmpty && phases.allSatisfy(\.isAssigned) }

    /// Summed minutes across time-based phases (distance phases can't be timed
    /// without a pace, so they're excluded — surface this as "~" in the UI).
    var estimatedMinutes: Int {
        let seconds = phases.reduce(0) { total, phase in
            if case .time(let s) = phase.goal { return total + s }
            return total
        }
        return seconds / 60
    }
}
