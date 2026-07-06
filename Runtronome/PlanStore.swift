import Foundation

/// Dead-simple persistence for user-built plans: one JSON blob in UserDefaults.
/// Also remembers which plan was last loaded into the metronome so a cold
/// launch restores it.
enum PlanStore {
    private static let plansKey = "runtronome.savedPlans"
    private static let activeKey = "runtronome.lastActivePlanID"

    static func load() -> [WorkoutPlan] {
        guard let data = UserDefaults.standard.data(forKey: plansKey) else { return [] }
        return (try? JSONDecoder().decode([WorkoutPlan].self, from: data)) ?? []
    }

    static func save(_ plans: [WorkoutPlan]) {
        if let data = try? JSONEncoder().encode(plans) {
            UserDefaults.standard.set(data, forKey: plansKey)
        }
    }

    /// Insert or replace by id; returns the updated list.
    @discardableResult
    static func upsert(_ plan: WorkoutPlan) -> [WorkoutPlan] {
        var plans = load()
        if let i = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[i] = plan
        } else {
            plans.append(plan)
        }
        save(plans)
        return plans
    }

    /// Garmin workout ids already in the library — the "already synced" set a
    /// re-sync checks against.
    static func garminWorkoutIds() -> Set<Int64> {
        Set(load().compactMap(\.garminWorkoutId))
    }

    /// Add freshly synced Garmin plans, skipping any whose workout id is
    /// already saved (never clobbers cadences the user already assigned).
    /// Returns the updated list.
    @discardableResult
    static func addNewGarmin(_ imported: [WorkoutPlan]) -> [WorkoutPlan] {
        var plans = load()
        let existing = Set(plans.compactMap(\.garminWorkoutId))
        for plan in imported where !(plan.garminWorkoutId.map(existing.contains) ?? true) {
            plans.append(plan)
        }
        save(plans)
        return plans
    }

    /// Returns the updated list.
    @discardableResult
    static func delete(_ id: UUID) -> [WorkoutPlan] {
        var plans = load()
        plans.removeAll { $0.id == id }
        save(plans)
        if lastActiveID == id { lastActiveID = nil }
        return plans
    }

    static var lastActiveID: UUID? {
        get { UserDefaults.standard.string(forKey: activeKey).flatMap(UUID.init) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: activeKey) }
    }
}
