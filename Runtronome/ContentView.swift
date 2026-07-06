import SwiftUI
import ActivityKit

struct ContentView: View {
    @State private var locationService = LocationService()

    // Seeded from the sync flow's MetronomeConfiguration (see init below).
    // Defaults preserve the original standalone behaviour for previews.
    @State private var isGarminConnected = true
    @State private var trainingTitle = "Goal Pace Repeats"
    @State private var phaseLabel = "WARM UP"
    @State private var plan: WorkoutPlan?

    @State private var spm: Double = 175
    @State private var isPlaying = false      // metronome ticking
    @State private var isPaused = false       // session active but held
    @State private var alertFrequency: AlertFrequency = .everyOther
    @State private var totalSteps = 0
    @State private var stepCount = 0
    @State private var metronomeTimer: Timer?
    @State private var currentTime = Date()
    @State private var clockTimer: Timer?
    @State private var hapticTrigger = 0
    @State private var isEditingSPM = false
    @State private var spmInputText = ""
    @State private var showingBuilder = false

    // Phase progression
    @State private var currentPhaseIndex = 0
    @State private var phaseRemaining = 0          // seconds left in current timed phase

    // Frequency spread picker
    @State private var isPickingFrequency = false

    @FocusState private var spmFieldFocused: Bool

    /// Single entry point — the sync flow injects the chosen workout/cadence here.
    /// With no injected plan, the last plan loaded from the library is restored.
    init(configuration: MetronomeConfiguration = .default) {
        var config = configuration
        if config.plan == nil,
           let id = PlanStore.lastActiveID,
           let saved = PlanStore.load().first(where: { $0.id == id }) {
            config = MetronomeConfiguration(plan: saved)
        }
        _trainingTitle = State(initialValue: config.trainingTitle)
        _phaseLabel = State(initialValue: config.phaseLabel)
        _isGarminConnected = State(initialValue: config.isGarminConnected)
        _spm = State(initialValue: Double(config.startingSPM))
        _plan = State(initialValue: config.plan)
    }

    private static let sound = MetronomeSound()
    @State private var liveActivity: Activity<RuntronomeActivityAttributes>?

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()
    private static let dayDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"; return f
    }()

    private var timeString: String { ContentView.timeFormatter.string(from: currentTime) }
    private var dayDateString: String { ContentView.dayDateFormatter.string(from: currentTime).uppercased() }

    /// Right side of the context row: "BELGRADE · 21° · 17:37".
    private var contextRight: String {
        [locationService.city.uppercased(), locationService.temperature, timeString]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    // MARK: Phase state

    private var currentPhase: WorkoutPhase? {
        guard let plan, plan.phases.indices.contains(currentPhaseIndex) else { return nil }
        return plan.phases[currentPhaseIndex]
    }

    private var nextPhase: WorkoutPhase? {
        guard let plan else { return nil }
        let i = currentPhaseIndex + 1
        return plan.phases.indices.contains(i) ? plan.phases[i] : nil
    }

    private var countdownString: String {
        String(format: "%d:%02d", phaseRemaining / 60, phaseRemaining % 60)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                Spacer()
                cadenceRail
                Spacer()
                footerView
            }
            .padding(.horizontal, 24)
            .blur(radius: isPickingFrequency ? 10 : 0)
            .allowsHitTesting(!isPickingFrequency)

            frequencyOverlay
        }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: hapticTrigger)
        .onAppear { setup() }
        .onDisappear { teardown() }
        .onChange(of: spm) { _, _ in
            guard !isEditingSPM else { return }
            syncWidget()
            if isPlaying { restartMetronome(); updateLiveActivity() }
        }
        .onChange(of: alertFrequency) { _, _ in syncWidget(); if isPlaying { updateLiveActivity() } }
        .onChange(of: phaseLabel) { _, _ in syncWidget(); if isPlaying { updateLiveActivity() } }
        .onChange(of: isGarminConnected) { _, _ in syncWidget() }
        .fullScreenCover(isPresented: $showingBuilder) {
            PlansFlowView(
                activePlanID: plan?.id,
                onApply: { applyPlan($0) },
                onClose: { showingBuilder = false }
            )
        }
    }

    // MARK: Header (masthead + phase block + context row)

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 0) {
            MastheadRule()

            // No plan loaded → no title; the masthead stays a clean rule + context.
            if plan != nil {
                Text(trainingTitle.uppercased())
                    .font(.anton(size: 30))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            phaseBlock

            contextRow
        }
        .padding(.top, 18)
    }

    /// Phase name + goal value + what's next. While idle it's a static preview
    /// of the loaded plan's first phase; once running it carries the live
    /// countdown and the advance bar for pause/distance phases.
    @ViewBuilder
    private var phaseBlock: some View {
        if let phase = currentPhase {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(phase.title.isEmpty ? "PHASE" : phase.title.uppercased())
                        .font(.momoTrust(size: 14, weight: .medium))
                        .tracking(1.2)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    phaseGoalValue(phase)
                }

                if let next = nextPhase {
                    Text("NEXT – \(nextSummary(next))")
                        .font(.momoTrust(size: 12, weight: .regular))
                        .tracking(1.2)
                        .foregroundColor(Theme.textSecondary)
                }

                if !isIdle {
                    phaseActionBar(phase)
                }

                Hairline().padding(.top, 10)
            }
        }
    }

    /// Timed phases show the goal while idle and the countdown once running;
    /// distance phases the goal. Pause phases carry no value — their whole
    /// row is the TAP TO CONTINUE bar below.
    @ViewBuilder
    private func phaseGoalValue(_ phase: WorkoutPhase) -> some View {
        switch phase.goal {
        case .time:
            Text(isIdle ? phase.goal.display.uppercased() : countdownString)
                .font(.momoTrust(size: 15, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
        case .distance(let meters):
            Text("\(meters) M")
                .font(.momoTrust(size: 15, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
        case .pause:
            EmptyView()
        }
    }

    private func nextSummary(_ next: WorkoutPhase) -> String {
        let title = next.title.isEmpty ? "PHASE" : next.title.uppercased()
        if case .pause = next.goal { return title }
        return "\(title) \(next.goal.display.uppercased())"
    }

    /// Full-width advance bar: white TAP TO CONTINUE for pause phases (the
    /// metronome is silent until tapped), black NEXT for distance phases
    /// (you're running; tap when you finish). Timed phases auto-advance.
    @ViewBuilder
    private func phaseActionBar(_ phase: WorkoutPhase) -> some View {
        switch phase.goal {
        case .pause:
            advanceBar("TAP TO CONTINUE", fill: Theme.ctaFill, label: Theme.ctaLabel)
        case .distance:
            advanceBar("NEXT", fill: Theme.ctaDark, label: .white)
        case .time:
            EmptyView()
        }
    }

    private func advanceBar(_ title: String, fill: Color, label: Color) -> some View {
        Button { advancePhase() } label: {
            HStack {
                Text(title)
                    .font(.anton(size: 15))
                    .tracking(0.5)
                Spacer()
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(label)
            .padding(.horizontal, 20)
            .frame(height: 54)
            .frame(maxWidth: .infinity)
            .background(Rectangle().fill(fill))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.top, 8)
    }

    private var contextRow: some View {
        HStack {
            MetaLabel(text: dayDateString)
            Spacer()
            MetaLabel(text: contextRight)
        }
        .padding(.vertical, 12)
    }

    // MARK: Cadence rail

    /// The poster centrepiece: the live SPM flanked by its faded neighbours,
    /// like a tape counter frozen mid-scroll. Drag up/down to slide the value;
    /// tap the centre number to type one.
    private let wheelRange = 30...300
    private let wheelRowHeight: CGFloat = 88
    private let wheelHeight: CGFloat = 396
    @State private var wheelSelection: Int?

    @ViewBuilder
    private var cadenceRail: some View {
        if isEditingSPM {
            spmEditor
        } else {
            spmWheel
        }
    }

    /// A real wheel (like the system timer picker): the whole column scrolls
    /// with your finger, decelerates, and snaps so the centre value is the
    /// live SPM. Tap the centre number to type instead.
    private var spmWheel: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(wheelRange, id: \.self) { value in
                    wheelRow(value)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $wheelSelection, anchor: .center)
        .scrollTargetBehavior(.viewAligned)
        .safeAreaPadding(.vertical, (wheelHeight - wheelRowHeight) / 2)
        .frame(height: wheelHeight)
        .sensoryFeedback(.selection, trigger: wheelSelection)
        .onAppear { wheelSelection = Int(spm) }
        .onChange(of: wheelSelection) { _, selected in
            if let selected, selected != Int(spm) { spm = Double(selected) }
        }
        .onChange(of: spm) { _, value in
            // External changes (plan load, Live Activity buttons) move the wheel.
            if wheelSelection != Int(value) { wheelSelection = Int(value) }
        }
    }

    /// Every row is set at full display size, then scaled/faded/repositioned by
    /// its distance from the centre to reproduce the original static rail
    /// exactly: ±1 at 58pt/38% white sitting 98pt out, ±2 at 40pt/28% white
    /// just 51pt further, nothing visible beyond. The curves are continuous so
    /// rows morph through those keyframes while the wheel spins.
    private func wheelRow(_ value: Int) -> some View {
        let rowHeight = wheelRowHeight
        return Text("\(value)")
            .font(.anton(size: 140))
            .foregroundColor(Theme.textPrimary)
            .lineLimit(1)
            .frame(height: rowHeight)
            .visualEffect { content, proxy in
                let container = proxy.bounds(of: .scrollView(axis: .vertical)) ?? .zero
                let raw = proxy.frame(in: .scrollView(axis: .vertical)).midY - container.midY
                // Measured empirically (see git history): with safeAreaPadding
                // this coordinate pair reports exactly 2× the real distance.
                let dist = abs(raw) / 2
                let sign: CGFloat = raw < 0 ? -1 : 1

                // Keyframes from the original poster rail:
                // hero 140pt/100% → ±1 66pt/38% → ±2 40pt/28% → gone.
                let scale = dist <= rowHeight
                    ? 1 - (dist / rowHeight) * (1 - 0.471)
                    : max(0.286, 0.471 - ((dist - rowHeight) / rowHeight) * (0.471 - 0.286))
                let opacity = dist <= rowHeight
                    ? 1 - (dist / rowHeight) * (1 - 0.38)
                    : dist <= rowHeight * 2
                        ? 0.38 - ((dist - rowHeight) / rowHeight) * (0.38 - 0.28)
                        : max(0, 0.28 - (dist - rowHeight * 2) / 24 * 0.28)

                // Remap positions to the poster's grouping: air around the
                // hero (±1 reads 111pt out), tight pair at the edges (±2 only
                // 56.5pt further). Offset must come after scaleEffect so the
                // translation isn't scaled down.
                let visualDist = dist <= rowHeight
                    ? dist * (111 / rowHeight)
                    : 111 + (dist - rowHeight) * (56.5 / rowHeight)

                return content
                    .scaleEffect(scale)
                    .offset(y: sign * (visualDist - dist))
                    .opacity(opacity)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if value == Int(spm) {
                    spmInputText = "\(value)"
                    isEditingSPM = true
                    spmFieldFocused = true
                } else {
                    withAnimation(.snappy) { wheelSelection = value }
                }
            }
    }

    private var spmEditor: some View {
        TextField("", text: $spmInputText)
            .font(.anton(size: 140))
            .foregroundColor(Theme.textPrimary)
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .focused($spmFieldFocused)
            .frame(height: wheelHeight)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { commitSPMEdit() }
                        .font(.momoTrust(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .onChange(of: spmFieldFocused) { _, focused in
                if !focused { commitSPMEdit() }
            }
    }

    // MARK: Footer (hairline + status row + transport)

    private var footerView: some View {
        VStack(spacing: 0) {
            Hairline()

            HStack {
                Button {
                    withAnimation(freqSpring) { isPickingFrequency = true }
                } label: {
                    HStack(spacing: 6) {
                        MetaLabel(text: alertFrequency.displayLabel)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Theme.textTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                MetaLabel(text: "\(totalSteps.formatted(.number)) TOTAL STEPS")
            }
            .padding(.vertical, 14)

            transportButtons
        }
        .padding(.bottom, 20)
    }

    // MARK: Transport (START → PAUSE | FINISH)

    private var isIdle: Bool { !isPlaying && !isPaused }

    /// One big START rectangle that splits into PAUSE/RESUME + FINISH while a
    /// session is active. The primary button is always present, so it animates
    /// from full-width to half as the side button changes.
    private var transportButtons: some View {
        HStack(spacing: 10) {
            // Left slot: new-plan button while idle, PAUSE/RESUME while active.
            if isIdle {
                newPlanButton
            } else {
                Button {
                    withAnimation(.bouncy) { pauseResumeAction() }
                } label: {
                    transportIcon(isPaused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.app(.secondary))
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            // Primary: play ⇄ stop. The symbol replaces in place (no cross-fade);
            // the layout springs as the side button changes.
            Button {
                withAnimation(.bouncy) { primaryTransportAction() }
            } label: {
                transportIcon(isIdle ? "play.fill" : "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.app(.primary))
        }
    }

    /// Opens the manual plan builder. Sits left of START while idle; disappears
    /// once a session starts.
    private var newPlanButton: some View {
        Button { showingBuilder = true } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Rectangle().fill(Theme.ctaDark))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    private func transportIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 20, weight: .bold))
            .contentTransition(.symbolEffect(.replace))
    }

    private func primaryTransportAction() {
        if isIdle { startSession() } else { finishSession() }
    }

    private func pauseResumeAction() {
        if isPaused { resumeSession() } else { pauseSession() }
    }

    // MARK: Frequency picker

    private var freqSpring: Animation { .spring(response: 0.38, dampingFraction: 0.85) }

    /// Options rise from the footer's frequency label — a flat stack of sharp
    /// rectangles, the active one inverted. Background dims; content blurs.
    private var frequencyOverlay: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black
                .opacity(isPickingFrequency ? 0.45 : 0)
                .ignoresSafeArea()
                .onTapGesture { collapseFrequency() }

            VStack(alignment: .leading, spacing: 2) {
                ForEach(AlertFrequency.allCases) { freq in
                    freqOption(freq, isSelected: freq == alertFrequency)
                }
            }
            .padding(.leading, 24)
            .padding(.bottom, 110)
            .opacity(isPickingFrequency ? 1 : 0)
            .offset(y: isPickingFrequency ? 0 : 28)
        }
        .allowsHitTesting(isPickingFrequency)
    }

    private func freqOption(_ freq: AlertFrequency, isSelected: Bool) -> some View {
        Button { selectFrequency(freq) } label: {
            Text(freq.displayLabel)
                .font(.momoTrust(size: 12, weight: .bold))
                .tracking(1.5)
                .foregroundColor(isSelected ? Theme.ctaLabel : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Rectangle().fill(isSelected ? Theme.ctaFill : Color(white: 0.24)))
        }
        .buttonStyle(.plain)
    }

    private func selectFrequency(_ freq: AlertFrequency) {
        alertFrequency = freq
        collapseFrequency()
    }

    private func collapseFrequency() {
        withAnimation(freqSpring) { isPickingFrequency = false }
    }

    // MARK: Phase advance

    private var isCurrentPhasePause: Bool {
        if case .pause = currentPhase?.goal { return true }
        return false
    }

    /// Seed the metronome from the current phase: label, cadence, and (if timed)
    /// the countdown. Re-syncs ticking so a pause phase falls silent and a normal
    /// phase resumes — `restartMetronome()` itself respects the pause.
    private func applyCurrentPhase() {
        guard let phase = currentPhase else { return }
        phaseLabel = phase.title.uppercased()
        if let target = phase.targetSPM, target > 0 {
            spm = Double(target)
        }
        if case .time(let seconds) = phase.goal {
            phaseRemaining = seconds
        } else {
            phaseRemaining = 0
        }
        if isPlaying { restartMetronome() }
    }

    private func advancePhase() {
        guard let plan else { return }
        let next = currentPhaseIndex + 1
        if plan.phases.indices.contains(next) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                currentPhaseIndex = next
            }
            applyCurrentPhase()
        } else {
            finishSession()   // workout complete — reset to START
        }
    }

    /// Called once per second from the clock timer; drives timed-phase auto-advance.
    private func tickPhaseCountdown() {
        guard isPlaying, let phase = currentPhase,
              case .time = phase.goal, phaseRemaining > 0 else { return }
        phaseRemaining -= 1
        if phaseRemaining == 0 { advancePhase() }
    }

    // MARK: Setup

    private func setup() {
        syncWidget()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            // Update clock display once per second
            let now = Date()
            if Int(now.timeIntervalSince1970) != Int(currentTime.timeIntervalSince1970) {
                currentTime = now
                tickPhaseCountdown()
            }
            // Sync SPM changed externally (Live Activity buttons) — onChange(of: spm) handles the rest
            let storedSPM = SharedStore.readSPM()
            if storedSPM != Int(spm) && !isEditingSPM {
                spm = Double(storedSPM)
            }
        }
    }

    private func syncWidget() {
        SharedStore.sync(
            spm: Int(spm),
            alertFrequency: alertFrequency.rawValue,
            phaseLabel: phaseLabel,
            isGarminConnected: isGarminConnected
        )
    }

    /// Apply a manually built plan to the live metronome: title + the first
    /// assigned phase seed the display/cadence. `onChange(of: spm)` handles
    /// restarting playback if the tempo actually changed.
    private func applyPlan(_ plan: WorkoutPlan) {
        self.plan = plan
        trainingTitle = plan.title
        isGarminConnected = true
        currentPhaseIndex = 0
        PlanStore.lastActiveID = plan.id
        applyCurrentPhase()
        // Phase 1 may have no cadence assigned — seed the wheel from the first
        // phase that does, so loading a plan is visible immediately.
        if (currentPhase?.targetSPM ?? 0) == 0,
           let lead = plan.phases.first(where: \.isAssigned)?.targetSPM {
            spm = Double(lead)
        }
        syncWidget()
    }

    private func teardown() {
        metronomeTimer?.invalidate()
        clockTimer?.invalidate()
    }

    // MARK: Session (START / PAUSE / RESUME / FINISH)

    private func startSession() {
        isPaused = false
        isPlaying = true
        stepCount = 0
        applyCurrentPhase()  // seed label/cadence/countdown from the first phase
        startLiveActivity()
        restartMetronome()   // schedules ticks unless the current phase is a pause
    }

    private func pauseSession() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
        isPlaying = false
        isPaused = true      // session stays up (Live Activity), just silent
    }

    private func resumeSession() {
        isPaused = false
        isPlaying = true
        restartMetronome()
    }

    private func finishSession() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
        endLiveActivity()
        isPlaying = false
        isPaused = false
        totalSteps = 0
        currentPhaseIndex = 0
        applyCurrentPhase()  // back to the first phase (won't tick — not playing)
    }

    /// (Re)schedule the tick timer — but stay silent on a pause phase, so the
    /// session keeps running (Live Activity stays up) while waiting for the user.
    private func restartMetronome() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
        guard !isCurrentPhasePause, spm > 0 else { return }
        let interval = 60.0 / spm
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in tick() }
    }

    private func commitSPMEdit() {
        if let parsed = Double(spmInputText) {
            spm = min(max(parsed.rounded(), Double(wheelRange.lowerBound)), Double(wheelRange.upperBound))
        }
        isEditingSPM = false
        spmFieldFocused = false
        syncWidget()
        if isPlaying { restartMetronome(); updateLiveActivity() }
    }

    // MARK: Live Activity

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = RuntronomeActivityAttributes(
            trainingTitle: trainingTitle,
            isGarminConnected: isGarminConnected
        )
        let state = RuntronomeActivityAttributes.ContentState(
            spm: Int(spm),
            alertFrequency: alertFrequency.rawValue,
            phaseLabel: phaseLabel
        )
        liveActivity = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: nil)
        )
    }

    private func updateLiveActivity(spmOverride: Int? = nil) {
        guard let activity = liveActivity else { return }
        let state = RuntronomeActivityAttributes.ContentState(
            spm: spmOverride ?? Int(spm),
            alertFrequency: alertFrequency.rawValue,
            phaseLabel: phaseLabel
        )
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    private func endLiveActivity() {
        Task {
            await liveActivity?.end(nil, dismissalPolicy: .immediate)
            liveActivity = nil
        }
    }

    private func tick() {
        totalSteps += 1
        stepCount += 1
        if stepCount % alertFrequency.stepInterval == 0 {
            ContentView.sound.play()
            hapticTrigger += 1
        }
    }
}

#Preview {
    ContentView()
}
