import SwiftUI

/// Summary card shown on the sync screen once a workout is fetched. Tapping it
/// advances to the phase editor.
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
            .joined(separator: "  –  ")
    }

    private var summaryLine: String {
        let phaseCount = "\(plan.phases.count) PHASES"
        let minutes = plan.estimatedMinutes
        return minutes > 0 ? "\(phaseCount)  ·  ~\(minutes) MIN" : phaseCount
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.title)
                        .font(.momoTrust(size: 20, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(contextLine)
                        .font(.momoTrust(size: 11, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                }

                Rectangle()
                    .fill(Theme.stroke)
                    .frame(height: 1)

                HStack {
                    Text(summaryLine)
                        .font(.momoTrust(size: 11, weight: .regular))
                        .foregroundColor(Theme.textTertiary)
                    Spacer()
                    Text("SET PACE")
                        .font(.momoTrust(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
