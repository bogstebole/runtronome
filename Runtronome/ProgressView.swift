import SwiftUI
import Charts

/// Heart-rate progress across like-for-like intervals. Pulls finished Garmin
/// runs, groups their laps by distance + pace, and charts how HR trends over
/// time — the same 800 m at the same pace, weeks apart.
struct RunProgressView: View {
    var onBack: () -> Void
    /// Called when the user isn't signed in yet — routes to the Garmin sign-in.
    var onNeedsSignIn: () -> Void

    private enum Phase {
        case loading(String)
        case groups([IntervalGroup])
        case detail(IntervalGroup)
        case empty
        case failed(String)
    }

    @State private var phase: Phase = .loading("READING YOUR RUNS…")

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 18)
                .padding(.horizontal, 24)

            content
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear(perform: startIfNeeded)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            MastheadRule()

            HStack(alignment: .center) {
                Button(action: backAction) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left").font(.system(size: 11, weight: .bold))
                        Text(backLabel).font(.appSans(size: 11, weight: .bold)).tracking(1.5)
                    }
                    .foregroundColor(Theme.textSecondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.vertical, 12)

            Text(headerTitle)
                .font(.anton(size: 30))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                MetaLabel(text: headerSubtitle)
                Spacer()
            }
            .padding(.bottom, 14)

            Hairline()
        }
    }

    private var headerTitle: String {
        if case .detail(let g) = phase { return "\(g.distanceLabel) · \(g.paceLabel)" }
        return "PROGRESS"
    }

    private var headerSubtitle: String {
        switch phase {
        case .detail: return "AVG HEART RATE PER SESSION"
        case .groups: return "PICK AN INTERVAL TO SEE HR TREND"
        default:      return "HEART RATE VS INTERVALS"
        }
    }

    private var backLabel: String {
        if case .detail = phase { return "INTERVALS" }
        return "PLANS"
    }

    private func backAction() {
        if case .detail(let g) = phase {
            // Rebuild the list from cache without a refetch.
            let groups = ProgressAnalytics.groups(from: ProgressStore.load())
            withAnimation(.easeInOut(duration: 0.2)) {
                phase = groups.isEmpty ? .empty : .groups(groups)
            }
            _ = g
        } else {
            onBack()
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading(let message):
            VStack(spacing: 18) {
                SyncSpinner(color: Theme.textPrimary, size: 34)
                MetaLabel(text: message, color: Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 80)

        case .groups(let groups):
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(groups) { group in
                        groupRow(group)
                    }
                }
                .padding(.horizontal, 24)
            }

        case .detail(let group):
            detailView(group)

        case .empty:
            VStack(spacing: 10) {
                Text("NOT ENOUGH DATA YET")
                    .font(.appSans(size: 14, weight: .medium))
                    .tracking(1.2)
                    .foregroundColor(Theme.textPrimary)
                Text("Run the same interval (same distance & pace) at least twice and it'll show up here.")
                    .font(.appSans(size: 12, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 80)

        case .failed(let message):
            VStack(spacing: 14) {
                Text("COULDN'T LOAD")
                    .font(.appSans(size: 14, weight: .medium)).tracking(1.2)
                    .foregroundColor(Theme.textPrimary)
                Text(message)
                    .font(.appSans(size: 13, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center).lineSpacing(3)
                    .padding(.horizontal, 40)
                Button("TRY AGAIN") { refresh() }
                    .buttonStyle(.app(.secondary, .compact))
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 70)
        }
    }

    // MARK: Group row

    private func groupRow(_ group: IntervalGroup) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { phase = .detail(group) }
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(group.distanceLabel) · \(group.paceLabel)")
                            .font(.appSans(size: 15, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                        MetaLabel(text: "\(group.sessionCount) SESSIONS", color: Theme.textTertiary)
                    }
                    Spacer(minLength: 12)
                    deltaBadge(group)
                }
                .padding(.vertical, 16)
                Hairline()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    /// HR change first → latest. Down is good; shown a touch brighter.
    private func deltaBadge(_ group: IntervalGroup) -> some View {
        HStack(spacing: 8) {
            if let latest = group.latestHR {
                Text("\(Int(latest.rounded()))")
                    .font(.anton(size: 22))
                    .foregroundColor(Theme.textPrimary)
                Text("BPM").font(.appSans(size: 9, weight: .bold)).tracking(1.0)
                    .foregroundColor(Theme.textTertiary)
            }
            if let delta = group.deltaHR, abs(delta) >= 1 {
                let down = delta < 0
                HStack(spacing: 2) {
                    Image(systemName: down ? "arrow.down" : "arrow.up")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(Int(abs(delta).rounded()))")
                        .font(.appSans(size: 11, weight: .bold))
                }
                .foregroundColor(down ? Theme.textPrimary : Theme.textSecondary)
            }
        }
    }

    // MARK: Detail (chart)

    private func detailView(_ group: IntervalGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Headline: first → latest.
            HStack(alignment: .firstTextBaseline, spacing: 20) {
                statColumn("FIRST", group.firstHR)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.textTertiary)
                    .padding(.top, 18)
                statColumn("LATEST", group.latestHR)
                Spacer()
                if let delta = group.deltaHR {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(delta < 0 ? "−" : "+")\(Int(abs(delta).rounded()))")
                            .font(.anton(size: 34))
                            .foregroundColor(Theme.textPrimary)
                        MetaLabel(text: delta < 0 ? "BPM LOWER" : "BPM HIGHER", color: Theme.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 24)

            chart(group)
                .frame(height: 260)
                .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func statColumn(_ label: String, _ hr: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            MetaLabel(text: label, color: Theme.textTertiary)
            Text(hr.map { "\(Int($0.rounded()))" } ?? "—")
                .font(.anton(size: 34))
                .foregroundColor(Theme.textPrimary)
        }
    }

    private func chart(_ group: IntervalGroup) -> some View {
        Chart(group.sessions) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("HR", point.avgHR)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(Theme.textPrimary)
            .lineStyle(StrokeStyle(lineWidth: 2))

            PointMark(
                x: .value("Date", point.date),
                y: .value("HR", point.avgHR)
            )
            .foregroundStyle(Theme.textPrimary)
            .symbolSize(60)
        }
        .chartYScale(domain: yDomain(group))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(Theme.textTertiary)
                    .font(.appSans(size: 10, weight: .regular))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Theme.hairline)
                AxisValueLabel().foregroundStyle(Theme.textTertiary)
                    .font(.appSans(size: 10, weight: .regular))
            }
        }
    }

    private func yDomain(_ group: IntervalGroup) -> ClosedRange<Double> {
        let hrs = group.sessions.map(\.avgHR)
        let lo = (hrs.min() ?? 120) - 6
        let hi = (hrs.max() ?? 180) + 6
        return lo...hi
    }

    // MARK: Loading

    private func startIfNeeded() {
        guard case .loading = phase else { return }
        guard GarminSession.isLoggedIn else {
            onNeedsSignIn()
            return
        }
        // Show cached immediately, then refresh in the background.
        let cachedGroups = ProgressAnalytics.groups(from: ProgressStore.load())
        if !cachedGroups.isEmpty { phase = .groups(cachedGroups) }
        refresh()
    }

    private func refresh() {
        if case .groups = phase {} else { phase = .loading("READING YOUR RUNS…") }
        Task {
            do {
                let fetcher = GarminConnectFetcher()
                let runs = try await fetcher.fetchRecentRuns(limit: 30)
                var cache = ProgressStore.load()
                let cachedIDs = Set(cache.map(\.activity.id))

                for (index, run) in runs.enumerated() where !cachedIDs.contains(run.id) {
                    phase = .loading("LOADING RUN \(index + 1)/\(runs.count)…")
                    cache.append(try await fetcher.fetchActivityDetail(run))
                }
                ProgressStore.save(cache)

                let groups = ProgressAnalytics.groups(from: cache)
                withAnimation(.easeInOut(duration: 0.2)) {
                    phase = groups.isEmpty ? .empty : .groups(groups)
                }
            } catch {
                // If we already showed cached groups, keep them; else surface error.
                if case .groups = phase { return }
                phase = .failed((error as? LocalizedError)?.errorDescription ?? "Something went wrong.")
            }
        }
    }
}
