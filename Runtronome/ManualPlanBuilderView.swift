import SwiftUI

/// Keyboard focus targets across the builder's dynamic text fields.
private enum BuilderField: Hashable {
    case title
    case phaseTitle(UUID)
    case note(UUID)
    case minutes(UUID)
    case seconds(UUID)
    case distance(UUID)
}

/// Manual plan builder — reached from the metronome's top-right icon. Lets the
/// user assemble a `WorkoutPlan` by hand (no syncing): name + description, then
/// add phases (title, time mm:ss or distance, target SPM) and "Save & Start".
struct ManualPlanBuilderView: View {
    var onCancel: () -> Void
    var onSave: (WorkoutPlan) -> Void

    @State private var title: String
    @State private var phases: [WorkoutPhase]
    @FocusState private var focused: BuilderField?

    /// Pass `existing` to edit an already-built plan; omit to start fresh.
    init(
        existing: WorkoutPlan? = nil,
        onCancel: @escaping () -> Void,
        onSave: @escaping (WorkoutPlan) -> Void
    ) {
        self.onCancel = onCancel
        self.onSave = onSave
        _title = State(initialValue: existing?.title ?? "My Plan")
        _phases = State(initialValue: existing?.phases ?? [])
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        planHeaderCard
                        ForEach($phases) { $phase in
                            BuilderPhaseRow(
                                phase: $phase,
                                focused: $focused,
                                onDelete: { delete(phase) }
                            )
                        }
                        addPhaseButton
                        if phases.isEmpty { emptyHint }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.interactively)

                footer
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = nil }
                    .font(.momoTrust(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        ZStack {
            Text("NEW PLAN")
                .font(.momoTrust(size: 11, weight: .regular))
                .foregroundColor(Theme.textTertiary)
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.control))
                        .contentShape(Circle())
                }
                .buttonStyle(PressableButtonStyle())
                Spacer()
            }
        }
    }

    // MARK: Plan header (name + description)

    private var planHeaderCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PLAN NAME")
                .font(.momoTrust(size: 10, weight: .regular))
                .foregroundColor(Theme.textTertiary)
            TextField("", text: $title, prompt: Text("Name your plan"))
                .font(.momoTrust(size: 22, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .tint(Theme.textPrimary)
                .focused($focused, equals: .title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
    }

    // MARK: Add / empty / footer

    private var addPhaseButton: some View {
        Button(action: addPhase) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("ADD PHASE")
                    .font(.momoTrust(size: 13, weight: .semibold))
            }
            .foregroundColor(Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Theme.stroke, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var emptyHint: some View {
        Text("Add phases to build your run.")
            .font(.momoTrust(size: 13, weight: .regular))
            .foregroundColor(Theme.textTertiary)
            .padding(.top, 4)
    }

    private var footer: some View {
        Button(action: save) {
            RuntronomeButton(style: .primary(text: "SAVE & START", systemImage: "play.fill"))
        }
        .buttonStyle(PressableButtonStyle())
        .opacity(phases.isEmpty ? 0.4 : 1)
        .disabled(phases.isEmpty)
    }

    // MARK: Actions

    private func addPhase() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            phases.append(WorkoutPhase(title: "", goal: .time(seconds: 300)))
        }
    }

    private func delete(_ phase: WorkoutPhase) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            phases.removeAll { $0.id == phase.id }
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let plan = WorkoutPlan(
            title: cleanTitle.isEmpty ? "My Plan" : cleanTitle,
            date: Date(),
            location: "",
            temperature: "",
            phases: phases
        )
        onSave(plan)
    }
}

// MARK: - Builder Row

/// One editable phase: title + delete, time (mm:ss) / distance entry, SPM.
private struct BuilderPhaseRow: View {
    @Binding var phase: WorkoutPhase
    @FocusState.Binding var focused: BuilderField?
    var onDelete: () -> Void

    private var isDistance: Bool {
        if case .distance = phase.goal { return true }
        return false
    }

    private var currentSeconds: Int {
        if case .time(let seconds) = phase.goal { return seconds }
        return 0
    }

    private var currentMeters: Int {
        if case .distance(let meters) = phase.goal { return meters }
        return 0
    }

    var body: some View {
        VStack(spacing: 14) {
            // Title (free text) + delete
            HStack {
                TextField("", text: $phase.title, prompt: Text("Phase title"))
                    .font(.momoTrust(size: 16, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .tint(Theme.textPrimary)
                    .focused($focused, equals: .phaseTitle(phase.id))

                Spacer(minLength: 8)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textTertiary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // Per-phase description
            TextField("", text: noteText, prompt: Text("Add a description"), axis: .vertical)
                .font(.momoTrust(size: 13, weight: .regular))
                .foregroundColor(Theme.textSecondary)
                .tint(Theme.textPrimary)
                .lineLimit(1...3)
                .focused($focused, equals: .note(phase.id))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Goal: time/distance toggle + typed value
            HStack(spacing: 12) {
                goalTypeToggle
                Spacer()
                if isDistance { distanceEntry } else { timeEntry }
            }

            Rectangle().fill(Theme.stroke).frame(height: 1)

            // Target SPM
            HStack {
                Text("TARGET SPM")
                    .font(.momoTrust(size: 11, weight: .regular))
                    .foregroundColor(Theme.textTertiary)
                Spacer()
                SPMStepper(value: $phase.targetSPM)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
    }

    // MARK: Goal type toggle

    private var goalTypeToggle: some View {
        HStack(spacing: 4) {
            // Tapping the already-active unit is a no-op so a typed value isn't wiped.
            toggleChip(title: "TIME", active: !isDistance) {
                if isDistance { phase.goal = .time(seconds: 300) }
            }
            toggleChip(title: "DIST", active: isDistance) {
                if !isDistance { phase.goal = .distance(meters: 400) }
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.background))
    }

    private func toggleChip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.momoTrust(size: 11, weight: .semibold))
                .foregroundColor(active ? Theme.ctaLabel : Theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(active ? Theme.ctaFill : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Value entry

    /// Minutes : seconds, each typed separately.
    private var timeEntry: some View {
        HStack(alignment: .top, spacing: 6) {
            timeField(minutesText, placeholder: "0", caption: "MIN", field: .minutes(phase.id))
            Text(":")
                .font(.momoTrust(size: 20, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
                .padding(.top, 2)
            timeField(secondsText, placeholder: "00", caption: "SEC", field: .seconds(phase.id))
        }
    }

    private func timeField(_ text: Binding<String>, placeholder: String, caption: String, field: BuilderField) -> some View {
        VStack(spacing: 2) {
            TextField(placeholder, text: text)
                .font(.momoTrust(size: 20, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .tint(Theme.textPrimary)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 46)
                .focused($focused, equals: field)
            Text(caption)
                .font(.momoTrust(size: 8, weight: .regular))
                .foregroundColor(Theme.textTertiary)
        }
    }

    private var distanceEntry: some View {
        HStack(spacing: 6) {
            TextField("0", text: distanceText)
                .font(.momoTrust(size: 20, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .tint(Theme.textPrimary)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .focused($focused, equals: .distance(phase.id))
            Text("M")
                .font(.momoTrust(size: 11, weight: .regular))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 24, alignment: .leading)
        }
    }

    // MARK: Bindings

    private var minutesText: Binding<String> {
        Binding(
            get: {
                let minutes = currentSeconds / 60
                return minutes == 0 ? "" : String(minutes)
            },
            set: { newValue in
                let minutes = Int(newValue.filter(\.isNumber)) ?? 0
                phase.goal = .time(seconds: minutes * 60 + currentSeconds % 60)
            }
        )
    }

    private var secondsText: Binding<String> {
        Binding(
            get: {
                let seconds = currentSeconds % 60
                return seconds == 0 ? "" : String(seconds)
            },
            set: { newValue in
                let seconds = min(Int(newValue.filter(\.isNumber)) ?? 0, 59)
                phase.goal = .time(seconds: (currentSeconds / 60) * 60 + seconds)
            }
        )
    }

    private var distanceText: Binding<String> {
        Binding(
            get: { currentMeters == 0 ? "" : String(currentMeters) },
            set: { newValue in
                phase.goal = .distance(meters: Int(newValue.filter(\.isNumber)) ?? 0)
            }
        )
    }

    private var noteText: Binding<String> {
        Binding(
            get: { phase.note ?? "" },
            set: { phase.note = $0.isEmpty ? nil : $0 }
        )
    }
}
