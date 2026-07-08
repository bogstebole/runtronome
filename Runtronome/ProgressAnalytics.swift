import Foundation

// MARK: - Interval progress analytics
//
// Groups laps across many runs into like-for-like intervals — same distance and
// same pace band — so heart rate can be compared fairly over time. Running an
// 800 m at 4:05 and later running another 800 m at 4:05 with a lower HR is real
// fitness; comparing different paces isn't, so pace is part of the key.

/// One run's contribution to an interval group: the average HR of that run's
/// laps in the group.
struct SessionPoint: Identifiable, Equatable {
    let id: Int64            // activityId
    let date: Date
    let avgHR: Double
    let avgPaceSecPerKm: Double
    let lapCount: Int
}

/// A set of like-for-like intervals tracked across sessions.
struct IntervalGroup: Identifiable, Equatable {
    let id: String
    let distance: Int        // metres, bucketed
    let paceBand: Int        // sec/km, lower bound of the pace band
    let sessions: [SessionPoint]   // sorted oldest → newest

    var sessionCount: Int { sessions.count }
    var firstHR: Double? { sessions.first?.avgHR }
    var latestHR: Double? { sessions.last?.avgHR }
    /// Negative = HR came down (improvement).
    var deltaHR: Double? {
        guard let f = firstHR, let l = latestHR else { return nil }
        return l - f
    }

    var distanceLabel: String {
        distance >= 1000 ? String(format: "%.1f KM", Double(distance) / 1000) : "\(distance) M"
    }

    var paceLabel: String { Self.paceString(Double(paceBand)) }

    static func paceString(_ secPerKm: Double) -> String {
        guard secPerKm.isFinite, secPerKm > 0 else { return "—" }
        let m = Int(secPerKm) / 60, s = Int(secPerKm) % 60
        return String(format: "%d:%02d/KM", m, s)
    }
}

enum ProgressAnalytics {
    /// Bucket sizes chosen so natural run-to-run variation clusters, but 800m@4:05
    /// and 800m@4:30 stay apart.
    private static let distanceBucket = 100     // metres
    private static let paceBucket = 15          // sec/km
    private static let minLapDistance = 200.0   // ignore tiny drills / GPS scraps

    static func groups(from details: [GarminActivityDetail]) -> [IntervalGroup] {
        // key → activityId → [ (hr, pace) ]
        var buckets: [String: [Int64: [(hr: Double, pace: Double)]]] = [:]
        var dates: [Int64: Date] = [:]

        for detail in details {
            dates[detail.activity.id] = detail.activity.date
            for lap in detail.laps {
                guard lap.distance >= minLapDistance,
                      let hr = lap.averageHR, hr > 0,
                      let pace = lap.paceSecPerKm else { continue }
                let distKey = Int((lap.distance / Double(distanceBucket)).rounded()) * distanceBucket
                let paceKey = Int(pace / Double(paceBucket)) * paceBucket
                let key = "\(distKey)-\(paceKey)"
                buckets[key, default: [:]][detail.activity.id, default: []].append((hr, pace))
            }
        }

        var groups: [IntervalGroup] = []
        for (key, byActivity) in buckets {
            let parts = key.split(separator: "-")
            guard parts.count == 2, let dist = Int(parts[0]), let pace = Int(parts[1]) else { continue }

            let sessions: [SessionPoint] = byActivity.compactMap { activityId, laps in
                guard let date = dates[activityId], !laps.isEmpty else { return nil }
                let avgHR = laps.map(\.hr).reduce(0, +) / Double(laps.count)
                let avgPace = laps.map(\.pace).reduce(0, +) / Double(laps.count)
                return SessionPoint(id: activityId, date: date, avgHR: avgHR,
                                    avgPaceSecPerKm: avgPace, lapCount: laps.count)
            }
            .sorted { $0.date < $1.date }

            // A trend needs at least two sessions.
            guard sessions.count >= 2 else { continue }
            groups.append(IntervalGroup(id: key, distance: dist, paceBand: pace, sessions: sessions))
        }

        // Surface the richest, fastest groups first — those are the work intervals
        // the runner cares about; slow recovery laps sink to the bottom.
        return groups.sorted {
            $0.sessionCount != $1.sessionCount ? $0.sessionCount > $1.sessionCount
                                               : $0.paceBand < $1.paceBand
        }
    }
}
