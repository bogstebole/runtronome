import SwiftUI

/// Summary card shown on the sync screen once a workout is fetched. Tapping it
/// advances to the phase editor. Flat Swiss sheet: hairline-framed, no rounding.
struct WorkoutPlanCard: View {
    let plan: WorkoutPlan
    var onTap: () -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter
    }()

    private var contextLine: String {
        [plan.location.uppercased(), plan.temperature, Self.dateFormatter.string(from: plan.date).uppercased()]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var summaryLine: String {
        let phaseCount = "\(plan.phases.count) PHASES"
        let minutes = plan.estimatedMinutes
        return minutes > 0 ? "\(phaseCount) · ~\(minutes) MIN" : phaseCount
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                Text(plan.title.uppercased())
                    .font(.anton(size: 24))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .padding(.bottom, 8)

                MetaLabel(text: contextLine)
                    .padding(.bottom, 16)

                Hairline()

                HStack {
                    MetaLabel(text: summaryLine, color: Theme.textTertiary)
                    Spacer()
                    HStack(spacing: 6) {
                        Text("SET PACE")
                            .font(.momoTrust(size: 11, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(Theme.textPrimary)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                    }
                }
                .padding(.top, 14)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Rectangle().fill(Theme.surface))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
