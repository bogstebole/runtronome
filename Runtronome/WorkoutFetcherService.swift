import Foundation

// MARK: - Workout Fetcher Service
//
// Sync strategy
// -------------
// Garmin's official structured-workout API is closed to indie developers, and
// Apple Health only stores *completed* activity (totals/segments) — never the
// *planned* phases + target paces this screen needs. So the data source is kept
// behind a protocol: the MVP ships `MockWorkoutFetcher` (a bundled Garmin-style
// JSON payload, so the UI can be built and demoed without any account), while
// `HealthKitWorkoutFetcher` scaffolds a real on-device source behind the exact
// same contract. Swapping sources is a one-line change in `RootFlowView` and the
// UI never has to know which one it's talking to.

/// Anything that can supply today's structured workout.
protocol WorkoutFetcherService {
    func fetchTodaysWorkout() async throws -> WorkoutPlan
}

/// Failures surfaced to the sync UI as readable copy.
enum WorkoutFetchError: LocalizedError {
    case noWorkoutFound
    case sourceUnavailable(String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .noWorkoutFound:
            return "No workout scheduled for today."
        case .sourceUnavailable(let reason):
            return reason
        case .decodingFailed:
            return "Couldn't read the workout data."
        }
    }
}
