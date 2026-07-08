import Foundation

// MARK: - Completed-activity models (heart-rate progress)
//
// Garmin records every run with per-lap heart rate, so tracking fitness is a
// read problem, not a measurement one. We pull finished running activities and
// their laps from the same unofficial Connect API used for planned workouts,
// then group like-for-like intervals (same distance + pace) to show how HR
// trends down over weeks.

/// One finished run.
struct GarminActivity: Codable, Identifiable, Equatable {
    let id: Int64            // activityId
    let name: String
    let date: Date
    let distance: Double     // metres
    let duration: Double     // seconds
    let averageHR: Double?
}

/// One lap within a run (a work interval or a recovery).
struct GarminLap: Codable, Equatable {
    let distance: Double     // metres
    let duration: Double     // seconds
    let averageHR: Double?
    let maxHR: Double?
    let averageSpeed: Double // m/s

    /// Seconds per kilometre; nil when the lap didn't move.
    var paceSecPerKm: Double? {
        averageSpeed > 0.1 ? 1000 / averageSpeed : nil
    }
}

/// A run plus its laps — the unit the analytics layer groups over.
struct GarminActivityDetail: Codable, Equatable {
    let activity: GarminActivity
    let laps: [GarminLap]
}

// MARK: - Fetcher

extension GarminConnectFetcher {
    private static let api = "https://connectapi.garmin.com"

    /// Recent running activities, most recent first.
    func fetchRecentRuns(limit: Int = 30) async throws -> [GarminActivity] {
        guard GarminSession.isLoggedIn else {
            throw WorkoutFetchError.sourceUnavailable("Sign in to Garmin first.")
        }
        let token = try await GarminSession.validAccessToken()
        let url = "\(Self.api)/activitylist-service/activities/search/activities?start=0&limit=\(limit)&activityType=running"
        let raw: [GarminActivityJSON] = try await getJSON(url, token: token)
        return raw.compactMap(GarminActivity.init(json:))
    }

    /// The laps (splits) of one activity.
    func fetchLaps(activityId: Int64) async throws -> [GarminLap] {
        let token = try await GarminSession.validAccessToken()
        let url = "\(Self.api)/activity-service/activity/\(activityId)/splits"
        let payload: GarminSplitsJSON = try await getJSON(url, token: token)
        return (payload.lapDTOs ?? []).map(GarminLap.init(json:))
    }

    /// A run plus its laps in one call.
    func fetchActivityDetail(_ activity: GarminActivity) async throws -> GarminActivityDetail {
        GarminActivityDetail(activity: activity, laps: try await fetchLaps(activityId: activity.id))
    }

    // MARK: Transport

    private func getJSON<T: Decodable>(_ urlString: String, token: String) async throws -> T {
        guard let url = URL(string: urlString) else { throw WorkoutFetchError.decodingFailed }
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
}

// MARK: - Raw JSON (only the fields we read; mapped into the clean models above)

private struct GarminActivityJSON: Codable {
    let activityId: Int64?
    let activityName: String?
    let startTimeLocal: String?
    let distance: Double?
    let duration: Double?
    let averageHR: Double?
}

private struct GarminSplitsJSON: Codable {
    let lapDTOs: [GarminLapJSON]?
}

private struct GarminLapJSON: Codable {
    let distance: Double?
    let duration: Double?
    let averageHR: Double?
    let maxHR: Double?
    let averageSpeed: Double?
}

private extension GarminActivity {
    init?(json: GarminActivityJSON) {
        guard let id = json.activityId else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        self.init(
            id: id,
            name: json.activityName ?? "Run",
            date: json.startTimeLocal.flatMap(formatter.date(from:)) ?? Date(),
            distance: json.distance ?? 0,
            duration: json.duration ?? 0,
            averageHR: json.averageHR
        )
    }
}

private extension GarminLap {
    init(json: GarminLapJSON) {
        self.init(
            distance: json.distance ?? 0,
            duration: json.duration ?? 0,
            averageHR: json.averageHR,
            maxHR: json.maxHR,
            averageSpeed: json.averageSpeed ?? 0
        )
    }
}
