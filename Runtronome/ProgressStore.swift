import Foundation

/// Caches fetched activity+lap details so the progress screen doesn't re-pull
/// every lap on each visit — only genuinely new runs are fetched.
enum ProgressStore {
    private static let key = "runtronome.activityDetails"

    static func load() -> [GarminActivityDetail] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([GarminActivityDetail].self, from: data)) ?? []
    }

    static func save(_ details: [GarminActivityDetail]) {
        if let data = try? JSONEncoder().encode(details) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func cachedIDs() -> Set<Int64> {
        Set(load().map(\.activity.id))
    }
}
