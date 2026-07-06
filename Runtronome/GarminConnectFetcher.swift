import Foundation

// MARK: - Garmin Connect workout fetcher (unofficial)
//
// Reads today's *planned* structured workout from Garmin Connect:
//   1. calendar-service/year/{y}/month/{m} → today's scheduled workoutId
//   2. workout-service/workout/{id}        → named steps + repeat groups
// and maps Garmin's step tree onto `WorkoutElement`s so the plan is fully
// editable in the builder and runnable by the metronome.

struct GarminConnectFetcher: WorkoutFetcherService {
    private static let api = "https://connectapi.garmin.com"

    func fetchTodaysWorkout() async throws -> WorkoutPlan {
        guard GarminSession.isLoggedIn else {
            throw WorkoutFetchError.sourceUnavailable("Sign in to Garmin first.")
        }
        let token = try await GarminSession.validAccessToken()

        let today = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: today)
        let month = calendar.component(.month, from: today) - 1   // Garmin months are 0-based

        let items: GarminCalendar = try await get(
            "\(Self.api)/calendar-service/year/\(year)/month/\(month)", token: token)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: today)

        guard let scheduled = items.calendarItems?.first(where: {
            $0.itemType == "workout" && $0.date == todayString && $0.workoutId != nil
        }) else {
            throw WorkoutFetchError.noWorkoutFound
        }

        let workout: GarminWorkout = try await get(
            "\(Self.api)/workout-service/workout/\(scheduled.workoutId!)", token: token)

        return Self.makePlan(from: workout, date: today)
    }

    private func get<T: Decodable>(_ urlString: String, token: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw WorkoutFetchError.decodingFailed
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("com.garmin.android.apps.connectmobile", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 401 || code == 403 {
                throw WorkoutFetchError.sourceUnavailable("Garmin session expired — sign in again.")
            }
            throw WorkoutFetchError.sourceUnavailable("Garmin returned an error (\(code)).")
        }
        guard let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            throw WorkoutFetchError.decodingFailed
        }
        return decoded
    }

    // MARK: Mapping Garmin's step tree → WorkoutElements

    static func makePlan(from workout: GarminWorkout, date: Date) -> WorkoutPlan {
        let steps = workout.workoutSegments?.flatMap { $0.workoutSteps ?? [] } ?? []
        let elements = steps.flatMap(elements(from:))
        return WorkoutPlan(
            title: workout.workoutName ?? "Garmin Workout",
            date: date,
            location: "",
            temperature: "",
            elements: elements,
            phases: elements.expandedPhases
        )
    }

    private static func elements(from step: GarminStep) -> [WorkoutElement] {
        guard step.type == "RepeatGroupDTO" else {
            return phase(from: step).map { [.step($0)] } ?? []
        }

        let children = (step.workoutSteps ?? []).flatMap(elements(from:))
        let childPhases = children.expandedPhases
        guard !childPhases.isEmpty else { return [] }
        let rounds = max(step.numberOfIterations ?? 1, 1)

        // Garmin repeats are usually work+rest pairs — that's exactly a
        // RepeatBlock. A single step repeats against a tap-to-continue rest.
        if childPhases.count == 2 {
            return [.block(RepeatBlock(title: "Repeat", work: childPhases[0], rest: childPhases[1], rounds: rounds))]
        }
        if childPhases.count == 1 {
            let rest = WorkoutPhase(title: "Rest", goal: .pause)
            return [.block(RepeatBlock(title: "Repeat", work: childPhases[0], rest: rest, rounds: rounds))]
        }

        // 3+ steps per round don't fit the block shape — expand every round
        // into numbered steps so nothing is lost (still fully editable).
        return (1...rounds).flatMap { round in
            childPhases.map { child in
                .step(WorkoutPhase(title: "\(child.title) \(round)", goal: child.goal,
                                   targetSPM: child.targetSPM, note: child.note))
            }
        }
    }

    private static func phase(from step: GarminStep) -> WorkoutPhase? {
        guard step.type == "ExecutableStepDTO" else { return nil }
        return WorkoutPhase(
            title: title(for: step),
            goal: goal(for: step),
            note: step.description
        )
    }

    private static func title(for step: GarminStep) -> String {
        switch step.stepType?.stepTypeKey {
        case "warmup":   return "Warm Up"
        case "cooldown": return "Cool Down"
        case "interval": return "Interval"
        case "recovery": return "Recovery"
        case "rest":     return "Rest"
        case "main":     return "Main"
        default:         return step.stepType?.stepTypeKey?.capitalized ?? "Step"
        }
    }

    private static func goal(for step: GarminStep) -> PhaseGoal {
        let value = step.endConditionValue ?? 0
        switch step.endCondition?.conditionTypeKey {
        case "time":
            return .time(seconds: max(Int(value), 1))
        case "distance":
            return .distance(meters: max(Int(value), 1))
        default:
            // lap.button and anything the metronome can't time (calories, HR)
            // becomes a hold: silent until the runner taps to continue.
            return .pause
        }
    }
}

// MARK: - Garmin JSON (only the fields this app reads)

struct GarminCalendar: Codable {
    let calendarItems: [GarminCalendarItem]?
}

struct GarminCalendarItem: Codable {
    let itemType: String?
    let date: String?
    let workoutId: Int64?
    let title: String?
}

struct GarminWorkout: Codable {
    let workoutName: String?
    let workoutSegments: [GarminSegment]?
}

struct GarminSegment: Codable {
    let workoutSteps: [GarminStep]?
}

struct GarminStep: Codable {
    let type: String?
    let stepType: GarminStepType?
    let description: String?
    let endCondition: GarminEndCondition?
    let endConditionValue: Double?
    let numberOfIterations: Int?
    let workoutSteps: [GarminStep]?   // present on RepeatGroupDTO
}

struct GarminStepType: Codable {
    let stepTypeKey: String?
}

struct GarminEndCondition: Codable {
    let conditionTypeKey: String?
}
