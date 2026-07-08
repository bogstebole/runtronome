import Foundation

// MARK: - Interval progress analytics
//
// One row per workout name (Hill Repeats, Speed Runs, Goal Pace Runs…). For
// each run of that workout we average the heart rate of its *work intervals
// only* — warm-up, cadence drills, accelerator glides and recoveries are all
// dropped — and chart that average over time. Same workout, weeks apart, lower
// HR = fitter.

/// One run's contribution to a workout trend: the average HR of that run's
/// work intervals.
struct SessionPoint: Identifiable, Equatable {
    let id: Int64            // activityId
    let date: Date
    let avgHR: Double
    let intervalCount: Int
}

/// A named workout tracked across sessions.
struct WorkoutTrend: Identifiable, Equatable {
    let id: String           // normalised workout name
    let name: String         // display name
    let sessions: [SessionPoint]   // sorted oldest → newest

    var sessionCount: Int { sessions.count }
    var firstDate: Date? { sessions.first?.date }
    var lastDate: Date? { sessions.last?.date }
    var firstHR: Double? { sessions.first?.avgHR }
    var latestHR: Double? { sessions.last?.avgHR }
    /// Negative = HR came down (improvement).
    var deltaHR: Double? {
        guard let f = firstHR, let l = latestHR else { return nil }
        return l - f
    }
}

enum ProgressAnalytics {
    private static let minLapDistance = 200.0   // ignore tiny drills / GPS scraps
    /// A lap counts as a work interval if its pace is within this factor of the
    /// session's fastest lap. Recovery jogs are far slower and drop out.
    private static let workPaceTolerance = 1.20

    /// One trend per workout name, most recently run first. Only runs with at
    /// least one identifiable work interval, and names done at least twice.
    static func trends(from details: [GarminActivityDetail]) -> [WorkoutTrend] {
        var byName: [String: (display: String, points: [SessionPoint])] = [:]

        for detail in details {
            let work = workIntervals(in: detail.laps)
            let hrs = work.compactMap(\.averageHR).filter { $0 > 0 }
            guard !hrs.isEmpty else { continue }

            let avgHR = hrs.reduce(0, +) / Double(hrs.count)
            let point = SessionPoint(id: detail.activity.id, date: detail.activity.date,
                                     avgHR: avgHR, intervalCount: hrs.count)
            let key = normalise(detail.activity.name)
            byName[key, default: (detail.activity.name, [])].points.append(point)
            byName[key]?.display = detail.activity.name
        }

        var trends: [WorkoutTrend] = []
        for (key, value) in byName {
            let sessions = value.points.sorted { $0.date < $1.date }
            guard sessions.count >= 2 else { continue }
            trends.append(WorkoutTrend(id: key, name: value.display, sessions: sessions))
        }
        return trends.sorted { ($0.lastDate ?? .distantPast) > ($1.lastDate ?? .distantPast) }
    }

    /// The running intervals in one activity: valid laps whose pace is close to
    /// the session's fastest. Warm-up, cool-down, drills and recovery laps are
    /// all much slower and fall away, leaving just the efforts.
    private static func workIntervals(in laps: [GarminLap]) -> [GarminLap] {
        let valid = laps.filter {
            $0.distance >= minLapDistance && ($0.averageHR ?? 0) > 0 && $0.paceSecPerKm != nil
        }
        guard let fastest = valid.compactMap(\.paceSecPerKm).min() else { return [] }
        return valid.filter { ($0.paceSecPerKm ?? .infinity) <= fastest * workPaceTolerance }
    }

    private static func normalise(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
