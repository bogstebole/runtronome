import SwiftUI

/// Plan library + builder flow, presented full-screen from the metronome.
/// Lists saved plans (load / edit / delete) and hosts the builder for new
/// plans and edits. Persistence lives in `PlanStore`.
struct PlansFlowView: View {
    var activePlanID: UUID?
    /// Called with the plan to load into the metronome.
    var onApply: (WorkoutPlan) -> Void
    var onClose: () -> Void

    private enum Mode: Equatable {
        case list
        case build(WorkoutPlan?)   // nil = new plan
        case sync                  // Garmin Connect login + bulk import
    }

    @State private var plans: [WorkoutPlan] = PlanStore.load()
    @State private var mode: Mode = .list

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch mode {
            case .list:
                listView
                    .transition(.opacity)

            case .build(let existing):
                ManualPlanBuilderView(
                    existing: existing,
                    onCancel: { withAnimation(.easeInOut(duration: 0.2)) { mode = .list } },
                    onSave: { plan in
                        plans = PlanStore.upsert(plan)
                        onApply(plan)
                        onClose()
                    }
                )
                .transition(.opacity)

            case .sync:
                GarminSyncView(
                    onBack: { withAnimation(.easeInOut(duration: 0.2)) { mode = .list } },
                    onImported: { imported in
                        // Merge into the library (skips duplicates), then land
                        // back on the list where the new plans show their status.
                        plans = PlanStore.addNewGarmin(imported)
                        withAnimation(.easeInOut(duration: 0.2)) { mode = .list }
                    }
                )
                .transition(.opacity)
            }
        }
    }

    // MARK: List

    private var listView: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 18)
                .padding(.horizontal, 24)

            if plans.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                // List (not ScrollView) purely for swipe-to-delete on the rows.
                List {
                    ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                        planRow(plan, index: index)
                            .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
                            .listRowBackground(Theme.background)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation(.snappy) { plans = PlanStore.delete(plan.id) }
                                } label: {
                                    Text("DELETE")
                                        .font(.momoTrust(size: 12, weight: .bold))
                                        .tracking(1.5)
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            VStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { mode = .sync }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.down").font(.system(size: 13, weight: .bold))
                        Text("SYNC FROM GARMIN")
                    }
                }
                .buttonStyle(.app(.secondary))

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { mode = .build(nil) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                        Text("NEW PLAN")
                    }
                }
                .buttonStyle(.app(.primary))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            MastheadRule()

            HStack(alignment: .center) {
                Text("PLANS")
                    .font(.anton(size: 30))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Rectangle().fill(Theme.control))
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.vertical, 12)

            HStack {
                MetaLabel(text: "TAP A PLAN TO LOAD IT")
                Spacer()
                MetaLabel(text: "\(plans.count) SAVED", color: Theme.textTertiary)
            }
            .padding(.bottom, 14)

            Hairline()
        }
    }

    /// Numbered sheet row: tap loads the plan; pencil edits; trash deletes.
    private func planRow(_ plan: WorkoutPlan, index: Int) -> some View {
        let isActive = plan.id == activePlanID
        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text(String(format: "%02d", index + 1))
                    .font(.anton(size: 20))
                    .foregroundColor(isActive ? Theme.textPrimary : Theme.railFar)
                    .frame(width: 34, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.title.uppercased())
                        .font(.momoTrust(size: 14, weight: .medium))
                        .tracking(1.0)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)

                    // Status lives in the meta line so the title keeps full
                    // width. "Needs pace" reads a touch brighter than the rest
                    // of the summary — present but not shouting.
                    HStack(spacing: 0) {
                        MetaLabel(text: rowSummary(plan, isActive: isActive),
                                  color: isActive ? Theme.textSecondary : Theme.textTertiary)
                        if plan.needsPace {
                            MetaLabel(text: " · NEEDS PACE", color: Theme.textSecondary)
                        }
                    }
                    .lineLimit(1)
                }

                Spacer(minLength: 12)

                rowButton("square.and.pencil") {
                    withAnimation(.easeInOut(duration: 0.2)) { mode = .build(plan) }
                }
            }
            .padding(.vertical, 14)

            Hairline()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onApply(plan)
            onClose()
        }
    }

    private static let rowDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f
    }()

    private func rowSummary(_ plan: WorkoutPlan, isActive: Bool) -> String {
        var parts: [String] = []
        // Garmin plans lead with their scheduled date so the calendar is legible.
        let hasDate = plan.isFromGarmin
        if hasDate {
            parts.append(Self.rowDateFormatter.string(from: plan.date).uppercased())
        }
        // A "NEEDS PACE" tag follows the summary. To keep the row on one line,
        // trim what it would push off: minutes always, and the phase count too
        // once there's a date to anchor the row.
        let count = plan.phases.count
        if !plan.needsPace || !hasDate {
            parts.append("\(count) \(count == 1 ? "PHASE" : "PHASES")")
        }
        let minutes = plan.estimatedMinutes
        if minutes > 0, !plan.needsPace { parts.append("~\(minutes) MIN") }
        if isActive { parts.append("LOADED") }
        return parts.joined(separator: " · ")
    }

    private func rowButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 40, height: 40)
                .overlay(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("NO PLANS YET")
                .font(.momoTrust(size: 14, weight: .medium))
                .tracking(1.2)
                .foregroundColor(Theme.textPrimary)
            Text("Build a workout once and it stays here —\nload, edit or duplicate it before every run.")
                .font(.momoTrust(size: 12, weight: .regular))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }
}
