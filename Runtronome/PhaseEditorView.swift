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
                .padding(.top, 64)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach($plan.phases) { $phase in
                        PhaseRow(phase: $phase)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            footer
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.control))
                        .contentShape(Circle())
                }
                .buttonStyle(PressableButtonStyle())

                Spacer()

                Text("\(plan.assignedCount)/\(plan.phases.count) SET")
                    .font(.momoTrust(size: 11, weight: .regular))
                    .foregroundColor(Theme.textTertiary)
            }

            VStack(spacing: 6) {
                Text("SET YOUR CADENCE")
                    .font(.momoTrust(size: 11, weight: .regular))
                    .foregroundColor(Theme.textTertiary)
                Text(plan.title)
                    .font(.momoTrust(size: 22, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        Button {
            onSaveStart(plan)
        } label: {
            RuntronomeButton(style: .primary(text: "SAVE & START", systemImage: "play.fill"))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// A single phase row: name + goal on the left, custom SPM stepper on the right.
private struct PhaseRow: View {
    @Binding var phase: WorkoutPhase

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(phase.title)
                    .font(.momoTrust(size: 16, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                Text(phase.goal.display)
                    .font(.momoTrust(size: 12, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer(minLength: 12)

            SPMStepper(value: $phase.targetSPM)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        .overlay(
            // Subtle left accent that brightens once a cadence is assigned.
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(phase.isAssigned ? Theme.textPrimary.opacity(0.25) : .clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: phase.isAssigned)
    }
}
