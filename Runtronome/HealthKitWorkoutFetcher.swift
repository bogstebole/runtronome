import Foundation
import HealthKit

// MARK: - HealthKit Workout Fetcher (real-source scaffold)
//
// Why this is a *bridge* and not the real planned-workout source
// ---------------------------------------------------------------
// HealthKit stores COMPLETED activity — totals plus, on iOS 16+, optional
// `HKWorkoutActivity` segments. Garmin's PLANNED structured workouts (named
// steps + target paces) are never written to Health. So phase names here are
// *inferred* (first = warm up, last = cool down, the rest = intervals) and
// `targetSPM` is always left nil for the user to assign. It demonstrates the
// real fetch path on-device; it does not magically recover the planned targets.
//
// To ACTIVATE:
//   1. Add the HealthKit capability to the Runtronome target.
//   2. Add `NSHealthShareUsageDescription` to Info.plist.
//   3. In `RootFlowView`, swap `MockWorkoutFetcher()` → `HealthKitWorkoutFetcher()`.
// Until configured it throws `.sourceUnavailable` rather than crashing on auth.

struct HealthKitWorkoutFetcher: WorkoutFetcherService {
    private let store = HKHealthStore()

    func fetchTodaysWorkout() async throws -> WorkoutPlan {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw WorkoutFetchError.sourceUnavailable("Health data isn't available on this device.")
        }
        // Requesting authorization without a usage string is a hard crash, so
        // refuse early if the app target hasn't been configured for HealthKit yet.
        guard Bundle.main.object(forInfoDictionaryKey: "NSHealthShareUsageDescription") != nil else {
            throw WorkoutFetchError.sourceUnavailable(
                "HealthKit isn't set up yet — see HealthKitWorkoutFetcher to enable it."
            )
        }

        let workoutType = HKObjectType.workoutType()
        try await store.requestAuthorization(toShare: [], read: [workoutType])

        guard let workout = try await mostRecentWorkout() else {
            throw WorkoutFetchError.noWorkoutFound
        }
        return Self.makePlan(from: workout)
    }

    /// Most recent workout recorded since midnight.
    private func mostRecentWorkout() async throws -> HKWorkout? {
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples?.first as? HKWorkout)
                }
            }
            store.execute(query)
        }
    }

    // MARK: Mapping

    private static func makePlan(from workout: HKWorkout) -> WorkoutPlan {
        WorkoutPlan(
            title: workout.workoutActivityType.displayName,
            date: workout.startDate,
            location: "—",
            temperature: "—",
            phases: inferPhases(from: workout)
        )
    }

    /// Map recorded segments to phases, inferring a title from position. Falls
    /// back to a single steady phase when the workout has no segmentation.
    private static func inferPhases(from workout: HKWorkout) -> [WorkoutPhase] {
        let activities = workout.workoutActivities
        guard !activities.isEmpty else {
            return [WorkoutPhase(title: "Steady", goal: .time(seconds: Int(workout.duration)))]
        }
        return activities.enumerated().map { index, activity in
            let title: String
            switch index {
            case 0:                      title = "Warm Up"
            case activities.count - 1:   title = "Cool Down"
            default:                     title = "Interval"
            }
            return WorkoutPhase(title: title, goal: .time(seconds: Int(activity.duration)))
        }
    }
}

private extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Ride"
        default:       return "Workout"
        }
    }
}
