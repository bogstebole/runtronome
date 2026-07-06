import SwiftUI

/// Keyboard focus targets across the builder's dynamic text fields.
private enum BuilderField: Hashable {
    case planTitle
    case elementTitle(UUID)
    case note(UUID)
    case minutes(UUID)
    case seconds(UUID)
    case distance(UUID)
    case spm(UUID)
}

/// Manual plan builder. A workout is a free, reorderable mix of elements:
/// single **steps** (warm up, a hold, cool down…) and **repeat blocks**
/// (work + rest × rounds). On save the structure expands into the flat phases
/// the metronome runs.
struct ManualPlanBuilderView: View {
    var onCancel: () -> Void
    var onSave: (WorkoutPlan) -> Void

    /// The plan being edited, if any — its identity/metadata survive the save
    /// so edits update the stored plan instead of duplicating it.
    private let source: WorkoutPlan?

    @State private var title: String
    @State private var elements: [WorkoutElement]
    @FocusState private var focused: BuilderField?

    init(
        existing: WorkoutPlan? = nil,
        onCancel: @escaping () -> Void,
        onSave: @escaping (WorkoutPlan) -> Void
    ) {
        self.onCancel = onCancel
        self.onSave = onSave
        self.source = existing
        _title = State(initialValue: existing?.title ?? "My Plan")
        _elements = State(initialValue: existing?.elements ?? [Self.makeStep("Warm Up", .time(seconds: 300))])
    }

    private static func makeStep(_ name: String, _ goal: PhaseGoal) -> WorkoutElement {
        .step(WorkoutPhase(title: name, goal: goal))
    }

    private static func makeBlock() -> WorkoutElement {
        .block(RepeatBlock(
            title: "Intervals",
            work: WorkoutPhase(title: "Work", goal: .distance(meters: 400)),
            rest: WorkoutPhase(title: "Rest", goal: .time(seconds: 120)),
            rounds: 6
        ))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                List {
                    planNameCard.plainRow()

                    // Touch-and-hold a card to drag and reorder.
                    ForEach($elements) { $element in
                        elementCard($element).plainRow()
                    }
                    .onMove { from, to in elements.move(fromOffsets: from, toOffset: to) }

                    addButtons.plainRow()
                    saveButton.plainRow(EdgeInsets(top: 10, leading: 20, bottom: 24, trailing: 20))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = nil }
                    .font(.appSans(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            MastheadRule()

            HStack(alignment: .center) {
                Text(source == nil ? "NEW PLAN" : "EDIT PLAN")
                    .font(.anton(size: 30))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button(action: onCancel) {
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

            Hairline()
        }
    }

    private var planNameCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PLAN NAME")
                .font(.appSans(size: 10, weight: .regular))
                .foregroundColor(Theme.textTertiary)
            TextField("", text: $title, prompt: Text("Name your plan"))
                .font(.appSans(size: 22, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .tint(Theme.textPrimary)
                .focused($focused, equals: .planTitle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(card)
    }

    // MARK: Element cards

    @ViewBuilder
    private func elementCard(_ element: Binding<WorkoutElement>) -> some View {
        if let phase = element.stepPhase {
            stepCard(phase: phase)
        } else if let block = element.repeatBlock {
            blockCard(block: block)
        }
    }

    private func stepCard(phase: Binding<WorkoutPhase>) -> some View {
        VStack(spacing: 12) {
            cardHeader(title: phase.title, id: phase.wrappedValue.id, placeholder: "Step name", badge: nil)
            StepEditor(phase: phase, focused: $focused, allowPause: true, showNote: true)
        }
        .padding(18)
        .background(card)
    }

    private func blockCard(block: Binding<RepeatBlock>) -> some View {
        VStack(spacing: 14) {
            cardHeader(title: block.title, id: block.wrappedValue.id, placeholder: "Block name", badge: "REPEAT")

            stepSection("WORK") {
                StepEditor(phase: block.work, focused: $focused, allowPause: false, showNote: false)
            }
            Hairline()
            stepSection("REST") {
                StepEditor(phase: block.rest, focused: $focused, allowPause: true, showNote: false)
            }
            Hairline()
            roundsRow(block.rounds)
        }
        .padding(18)
        .background(card)
        .overlay(
            Rectangle()
                .strokeBorder(Theme.textPrimary.opacity(0.14), lineWidth: 1)
        )
    }

    private func cardHeader(title: Binding<String>, id: UUID, placeholder: String, badge: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")   // decorative reorder cue
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 22)

            TextField("", text: title, prompt: Text(placeholder))
                .font(.appSans(size: 16, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .tint(Theme.textPrimary)
                .focused($focused, equals: .elementTitle(id))

            if let badge {
                Text(badge)
                    .font(.appSans(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(Theme.textTertiary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Rectangle().fill(Theme.surfaceRaised))
            }

            Button { delete(id) } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.textTertiary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func stepSection<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.appSans(size: 11, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            content()
        }
    }

    private func roundsRow(_ rounds: Binding<Int>) -> some View {
        HStack(spacing: 12) {
            Text("ROUNDS")
                .font(.appSans(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
                .frame(width: 84, alignment: .leading)
            Spacer(minLength: 8)
            HStack(spacing: 14) {
                roundButton("minus") { if rounds.wrappedValue > 1 { rounds.wrappedValue -= 1 } }
                Text("\(rounds.wrappedValue)")
                    .font(.anton(size: 22))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .frame(minWidth: 30)
                    .contentTransition(.numericText())
                roundButton("plus") { if rounds.wrappedValue < 50 { rounds.wrappedValue += 1 } }
            }
        }
    }

    private func roundButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Rectangle().fill(Theme.control))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Add / save

    private var addButtons: some View {
        HStack(spacing: 10) {
            dashedButton("ADD STEP", "plus") {
                withAnimation(.snappy) { elements.append(Self.makeStep("Step", .time(seconds: 300))) }
            }
            dashedButton("ADD INTERVAL", "repeat") {
                withAnimation(.snappy) { elements.append(Self.makeBlock()) }
            }
        }
    }

    private func dashedButton(_ label: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                Text(label).font(.appSans(size: 12, weight: .bold)).tracking(1.2)
            }
            .foregroundColor(Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Rectangle()
                    .strokeBorder(Theme.stroke, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var saveButton: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill").font(.system(size: 14, weight: .semibold))
                Text("SAVE & START")
            }
        }
        .buttonStyle(.app(.primary))
        .opacity(elements.isEmpty ? 0.4 : 1)
        .disabled(elements.isEmpty)
    }

    private func delete(_ id: UUID) {
        withAnimation(.snappy) { elements.removeAll { $0.id == id } }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let plan = WorkoutPlan(
            id: source?.id ?? UUID(),
            title: cleanTitle.isEmpty ? "My Plan" : cleanTitle,
            date: source?.date ?? Date(),
            location: source?.location ?? "",
            temperature: source?.temperature ?? "",
            elements: elements,
            phases: elements.expandedPhases
        )
        onSave(plan)
    }

    private var card: some View {
        Rectangle().fill(Theme.surface)
    }
}

// MARK: - Binding into a WorkoutElement's case

private extension Binding where Value == WorkoutElement {
    var stepPhase: Binding<WorkoutPhase>? {
        guard case .step(let phase) = wrappedValue else { return nil }
        return Binding<WorkoutPhase>(
            get: { if case .step(let p) = wrappedValue { return p } else { return phase } },
            set: { wrappedValue = .step($0) }
        )
    }

    var repeatBlock: Binding<RepeatBlock>? {
        guard case .block(let block) = wrappedValue else { return nil }
        return Binding<RepeatBlock>(
            get: { if case .block(let b) = wrappedValue { return b } else { return block } },
            set: { wrappedValue = .block($0) }
        )
    }
}

// MARK: - List row styling

private extension View {
    /// Strips List chrome; uses the screen background so a lifted row during
    /// reorder shows the dark backdrop instead of a black default-cell flash.
    func plainRow(_ insets: EdgeInsets = EdgeInsets(top: 7, leading: 20, bottom: 7, trailing: 20)) -> some View {
        listRowInsets(insets)
            .listRowBackground(Theme.background)
            .listRowSeparator(.hidden)
    }
}

// MARK: - Step editor (one phase: description, goal, target SPM)

private struct StepEditor: View {
    @Binding var phase: WorkoutPhase
    @FocusState.Binding var focused: BuilderField?
    var allowPause: Bool
    var showNote: Bool

    private var isTime: Bool { if case .time = phase.goal { return true }; return false }
    private var isDistance: Bool { if case .distance = phase.goal { return true }; return false }
    private var isPause: Bool { if case .pause = phase.goal { return true }; return false }
    private var currentSeconds: Int { if case .time(let s) = phase.goal { return s }; return 0 }
    private var currentMeters: Int { if case .distance(let m) = phase.goal { return m }; return 0 }

    /// A flat table: fixed label lane on the left, controls on the right,
    /// hairlines between rows — every value has an anchor.
    var body: some View {
        VStack(spacing: 0) {
            row("GOAL") { goalToggle }

            if isPause {
                Hairline()
                Text("Pauses until you tap to continue.")
                    .font(.appSans(size: 12, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                Hairline()
                row(isTime ? "DURATION" : "DISTANCE") {
                    if isTime { timeEntry } else { distanceEntry }
                }
                Hairline()
                row("TARGET SPM") {
                    NumberField(
                        value: $phase.targetSPM,
                        range: 0...300,
                        caption: "SPM",
                        focused: $focused,
                        field: .spm(phase.id)
                    )
                }
            }

            if showNote {
                Hairline()
                noteRow
            }
        }
    }

    /// Label lane (fixed width) + right-aligned control.
    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.appSans(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
                .frame(width: 84, alignment: .leading)
            Spacer(minLength: 8)
            content()
        }
        .padding(.vertical, 10)
    }

    private var noteRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("NOTE")
                .font(.appSans(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
                .frame(width: 84, alignment: .leading)
            TextField("", text: noteText,
                      prompt: Text("Add a description").foregroundStyle(Theme.textTertiary),
                      axis: .vertical)
                .font(.appSans(size: 13, weight: .regular))
                .foregroundColor(Theme.textSecondary)
                .tint(Theme.textPrimary)
                .lineLimit(1...3)
                .focused($focused, equals: .note(phase.id))
        }
        .padding(.vertical, 12)
    }

    private var goalToggle: some View {
        HStack(spacing: 3) {
            chip("TIME", active: isTime) { if !isTime { phase.goal = .time(seconds: 300) } }
            chip("DIST", active: isDistance) { if !isDistance { phase.goal = .distance(meters: 400) } }
            if allowPause {
                chip("PAUSE", active: isPause) {
                    if !isPause { phase.goal = .pause; phase.targetSPM = nil }
                }
            }
        }
        .padding(3)
        .background(Rectangle().fill(Theme.background))
    }

    private func chip(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.appSans(size: 11, weight: .bold))
                .tracking(1.0)
                .foregroundColor(active ? Theme.ctaLabel : Theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Rectangle().fill(active ? Theme.ctaFill : Color.clear))
        }
        .buttonStyle(.plain)
    }

    // MARK: Value entry (slide or type)

    private var timeEntry: some View {
        HStack(alignment: .top, spacing: 8) {
            NumberField(
                value: minutesValue, range: 0...180,
                caption: "MIN", width: 48,
                focused: $focused, field: .minutes(phase.id)
            )
            Text(":")
                .font(.anton(size: 20))
                .foregroundColor(Theme.textTertiary)
                .padding(.top, 3)
            NumberField(
                value: secondsValue, range: 0...59,
                caption: "SEC", width: 48,
                focused: $focused, field: .seconds(phase.id)
            )
        }
    }

    private var distanceEntry: some View {
        HStack(spacing: 8) {
            NumberField(
                value: distanceValue, range: 0...50000,
                caption: nil, width: 76,
                focused: $focused, field: .distance(phase.id)
            )
            Text("M")
                .font(.appSans(size: 11, weight: .regular))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
        }
    }

    // MARK: Bindings into the goal

    private var noteText: Binding<String> {
        Binding(get: { phase.note ?? "" }, set: { phase.note = $0.isEmpty ? nil : $0 })
    }

    private var minutesValue: Binding<Int?> {
        Binding(
            get: { let m = currentSeconds / 60; return m == 0 ? nil : m },
            set: { phase.goal = .time(seconds: ($0 ?? 0) * 60 + currentSeconds % 60) }
        )
    }

    private var secondsValue: Binding<Int?> {
        Binding(
            get: { let s = currentSeconds % 60; return s == 0 ? nil : s },
            set: { phase.goal = .time(seconds: (currentSeconds / 60) * 60 + min($0 ?? 0, 59)) }
        )
    }

    private var distanceValue: Binding<Int?> {
        Binding(
            get: { currentMeters == 0 ? nil : currentMeters },
            set: { phase.goal = .distance(meters: $0 ?? 0) }
        )
    }
}
