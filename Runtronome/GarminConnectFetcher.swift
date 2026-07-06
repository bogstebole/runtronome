import Foundation

// MARK: - Garmin Connect workout fetcher (unofficial)
//
// Reads today's *planned* structured workout from Garmin Connect:
//   1. calendar-service/year/{y}/month/{m} → today's scheduled workoutId
//   2. workout-service/workout/{id}        → named steps + repeat groups
// and maps Garmin's step tree onto `WorkoutElement`s so the plan is fully
// editable in the builder and runnable by the metronome.

/// One scheduled workout on the Garmin calendar — enough to list it before
/// pulling its full structure on tap.
struct GarminScheduledWorkout: Identifiable, Equatable {
    let id: Int64        // workoutId
    let date: Date
    let title: String
}

struct GarminConnectFetcher: WorkoutFetcherService {
    private static let api = "https://connectapi.garmin.com"

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Every scheduled workout from today through `daysAhead`, sorted soonest
    /// first. Pulls each calendar month the window spans (Garmin months are
    /// 0-based) and keeps only workout items with a structure to fetch.
    func fetchUpcoming(daysAhead: Int = 45) async throws -> [GarminScheduledWorkout] {
        guard GarminSession.isLoggedIn else {
            throw WorkoutFetchError.sourceUnavailable("Sign in to Garmin first.")
        }
        let token = try await GarminSession.validAccessToken()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let horizon = calendar.date(byAdding: .day, value: daysAhead, to: today) ?? today

        var results: [GarminScheduledWorkout] = []
        for (year, month) in months(from: today, to: horizon, calendar: calendar) {
            let page: GarminCalendar = try await get(
                "\(Self.api)/calendar-service/year/\(year)/month/\(month)", token: token)
            for item in page.calendarItems ?? [] {
                guard item.itemType == "workout",
                      let id = item.workoutId,
                      let dateString = item.date,
                      let date = Self.dayFormatter.date(from: dateString),
                      date >= today, date <= horizon
                else { continue }
                results.append(GarminScheduledWorkout(
                    id: id, date: date, title: item.title ?? "Workout"))
            }
        }
        return results.sorted { $0.date < $1.date }
    }

    /// Full structured plan for one scheduled workout.
    func fetchWorkout(_ scheduled: GarminScheduledWorkout) async throws -> WorkoutPlan {
        let token = try await GarminSession.validAccessToken()
        let workout: GarminWorkout = try await get(
            "\(Self.api)/workout-service/workout/\(scheduled.id)", token: token)
        return Self.makePlan(from: workout, date: scheduled.date, garminWorkoutId: scheduled.id)
    }

    func fetchTodaysWorkout() async throws -> WorkoutPlan {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let todays = try await fetchUpcoming(daysAhead: 0).first(where: {
            calendar.isDate($0.date, inSameDayAs: today)
        }) else {
            throw WorkoutFetchError.noWorkoutFound
        }
        return try await fetchWorkout(todays)
    }

    /// The (year, month0) calendar pages a date window touches. `month0` is
    /// 0-based to match Garmin's API.
    private func months(from start: Date, to end: Date, calendar: Calendar) -> [(Int, Int)] {
        var pairs: [(Int, Int)] = []
        var cursor = calendar.date(from: calendar.dateComponents([.year, .month], from: start)) ?? start
        let endMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: end)) ?? end
        while cursor <= endMonth {
            let comps = calendar.dateComponents([.year, .month], from: cursor)
            if let year = comps.year, let month = comps.month {
                pairs.append((year, month - 1))
            }
            cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? endMonth.addingTimeInterval(1)
        }
        return pairs
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

    static func makePlan(from workout: GarminWorkout, date: Date, garminWorkoutId: Int64? = nil) -> WorkoutPlan {
        let steps = workout.workoutSegments?.flatMap { $0.workoutSteps ?? [] } ?? []
        let elements = steps.flatMap(elements(from:))
        return WorkoutPlan(
            title: workout.workoutName ?? "Garmin Workout",
            date: date,
            location: "",
            temperature: "",
            garminWorkoutId: garminWorkoutId,
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
