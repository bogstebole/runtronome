import Foundation

// MARK: - Mock Workout Fetcher
//
// The MVP default source. It decodes a bundled Garmin-style JSON payload — going
// through the real fetch → decode path on purpose, so the `Codable` models are
// proven and a live API can later replace the payload with zero UI changes.
// A short artificial latency makes the sync UI's loading state feel real.

struct MockWorkoutFetcher: WorkoutFetcherService {
    /// Simulated network round-trip.
    var latency: Duration = .milliseconds(900)

    func fetchTodaysWorkout() async throws -> WorkoutPlan {
        try await Task.sleep(for: latency)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(WorkoutPlan.self, from: Data(Self.sampleJSON.utf8))
        } catch {
            throw WorkoutFetchError.decodingFailed
        }
    }

    /// A representative structured interval session. A couple of phases ship with
    /// a target SPM pre-filled so the editor shows both assigned and unassigned
    /// states; the work intervals are left blank for the user to dial in.
    private static let sampleJSON = """
    {
        "id": "7C4F1A20-0000-0000-0000-000000000001",
        "title": "Goal Pace Repeats",
        "date": "2026-06-22T07:30:00Z",
        "location": "London",
        "temperature": "14°",
        "phases": [
            {
                "id": "00000000-0000-0000-0000-000000000001",
                "title": "Warm Up",
                "goal": { "time": { "seconds": 600 } },
                "targetSPM": 160
            },
            {
                "id": "00000000-0000-0000-0000-000000000002",
                "title": "Interval",
                "goal": { "distance": { "meters": 800 } }
            },
            {
                "id": "00000000-0000-0000-0000-000000000003",
                "title": "Recovery",
                "goal": { "time": { "seconds": 120 } }
            },
            {
                "id": "00000000-0000-0000-0000-000000000004",
                "title": "Interval",
                "goal": { "distance": { "meters": 800 } }
            },
            {
                "id": "00000000-0000-0000-0000-000000000005",
                "title": "Recovery",
                "goal": { "time": { "seconds": 120 } }
            },
            {
                "id": "00000000-0000-0000-0000-000000000006",
                "title": "Interval",
                "goal": { "distance": { "meters": 800 } }
            },
            {
                "id": "00000000-0000-0000-0000-000000000007",
                "title": "Cool Down",
                "goal": { "time": { "seconds": 600 } },
                "targetSPM": 155
            }
        ]
    }
    """
}
