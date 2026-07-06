import SwiftUI

/// View 2 — list every phase of the fetched workout and let the user assign a
/// target SPM to each via a custom stepper. "Save & Start" hands the configured
/// plan back to the coordinator, which seeds and shows the metronome.
struct PhaseEditorView: View {
    @Binding var plan: WorkoutPlan
    var onBack: () -> Void
    var onSaveStart: (WorkoutPlan) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 18)
                .padding(.horizontal, 24)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(plan.phases.enumerated()), id: \.element.id) { index, _ in
                        PhaseRow(index: index, phase: $plan.phases[index])
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            footer
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            MastheadRule()

            HStack(alignment: .center) {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("BACK")
                            .font(.momoTrust(size: 11, weight: .bold))
                            .tracking(1.5)
                    }
                    .foregroundColor(Theme.textSecondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                MetaLabel(text: "\(plan.assignedCount)/\(plan.phases.count) SET",
                          color: plan.allAssigned ? Theme.textPrimary : Theme.textSecondary)
            }
            .padding(.vertical, 12)

            Text(plan.title.uppercased())
                .font(.anton(size: 30))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                MetaLabel(text: "SET YOUR CADENCE")
                Spacer()
                MetaLabel(text: "SPM PER PHASE", color: Theme.textTertiary)
            }
            .padding(.bottom, 14)

            Hairline()
        }
    }

    // MARK: Footer

    private var footer: some View {
        Button {
            onSaveStart(plan)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill").font(.system(size: 13, weight: .bold))
                Text("SAVE & START")
            }
        }
        .buttonStyle(.app(.primary))
    }
}

/// A single phase row on the sheet: numbered index + name + goal on the left,
/// custom SPM stepper on the right, hairline underneath. The index lights up
/// once a cadence is assigned.
private struct PhaseRow: View {
    let index: Int
    @Binding var phase: WorkoutPhase

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text(String(format: "%02d", index + 1))
                    .font(.anton(size: 20))
                    .foregroundColor(phase.isAssigned ? Theme.textPrimary : Theme.railFar)
                    .frame(width: 34, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text(phase.title.uppercased())
                        .font(.momoTrust(size: 14, weight: .medium))
                        .tracking(1.0)
                        .foregroundColor(Theme.textPrimary)
                    MetaLabel(text: phase.goal.display.uppercased(), color: Theme.textTertiary)
                }

                Spacer(minLength: 12)

                SPMStepper(value: $phase.targetSPM)
            }
            .padding(.vertical, 14)

            Hairline()
        }
        .animation(.easeInOut(duration: 0.2), value: phase.isAssigned)
    }
}
