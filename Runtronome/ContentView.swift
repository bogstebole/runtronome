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
    @State private var isPlaying = false
    @State private var alertFrequency: AlertFrequency = .everyOther
    @State private var totalSteps = 0
    @State private var stepCount = 0
    @State private var metronomeTimer: Timer?
    @State private var currentTime = Date()
    @State private var clockTimer: Timer?
    @State private var hapticTrigger = 0
    @State private var isSliderActive = false
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
    init(configuration: MetronomeConfiguration = .default) {
        _trainingTitle = State(initialValue: configuration.trainingTitle)
        _phaseLabel = State(initialValue: configuration.phaseLabel)
        _isGarminConnected = State(initialValue: configuration.isGarminConnected)
        _spm = State(initialValue: Double(configuration.startingSPM))
        _plan = State(initialValue: configuration.plan)
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

    private var contextLine: String {
        [locationService.city, locationService.temperature, timeString, dayDateString]
            .filter { !$0.isEmpty }
            .joined(separator: "  –  ")
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
            Color(white: 0.165).ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                    .scaleEffect(isSliderActive ? 0.85 : 1.0)
                    .opacity(isSliderActive ? 0.5 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSliderActive)
                Spacer()
                centralView
                    .scaleEffect(isSliderActive ? 0.85 : 1.0)
                    .opacity(isSliderActive ? 0.5 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSliderActive)
                Spacer()
                footerView
            }
            .overlay(alignment: .topTrailing) { planButton }
            .scaleEffect(isPickingFrequency ? 0.85 : 1.0)
            .blur(radius: isPickingFrequency ? 18 : 0)
            .allowsHitTesting(!isPickingFrequency)

            frequencyOverlay
        }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: hapticTrigger)
        .onAppear { setup() }
        .onDisappear { teardown() }
        .onChange(of: spm) { _, _ in
            guard !isSliderActive && !isEditingSPM else { return }
            syncWidget()
            if isPlaying { restartMetronome(); updateLiveActivity() }
        }
        .onChange(of: alertFrequency) { _, _ in syncWidget(); if isPlaying { updateLiveActivity() } }
        .onChange(of: phaseLabel) { _, _ in syncWidget(); if isPlaying { updateLiveActivity() } }
        .onChange(of: isGarminConnected) { _, _ in syncWidget() }
        .fullScreenCover(isPresented: $showingBuilder) {
            ManualPlanBuilderView(
                onCancel: { showingBuilder = false },
                onSave: { plan in
                    applyPlan(plan)
                    showingBuilder = false
                }
            )
        }
    }

    // MARK: Subviews

    /// Top-right affordance to open the manual plan builder.
    private var planButton: some View {
        Button { showingBuilder = true } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color(white: 0.28)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .padding(.trailing, 20)
        .opacity(isSliderActive ? 0 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSliderActive)
    }

    private var headerView: some View {
        VStack(spacing: 6) {
            if isGarminConnected {
                Text(trainingTitle)
                    .font(.momoTrust(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            Text(contextLine)
                .font(.momoTrust(size: 11, weight: .regular))
                .foregroundColor(Color(white: 0.5))
        }
        .padding(.top, 56)
        .padding(.horizontal, 24)
    }

    private var centralView: some View {
        VStack(spacing: 0) {
            phaseHeader

            Group {
                if isEditingSPM {
                    TextField("", text: $spmInputText)
                        .font(.momoTrust(size: 130, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .focused($spmFieldFocused)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") { commitSPMEdit() }
                                    .font(.momoTrust(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                } else {
                    Text("\(Int(spm))")
                        .font(.momoTrust(size: 130, weight: .bold))
                        .foregroundColor(.white)
                        .onTapGesture {
                            spmInputText = "\(Int(spm))"
                            isEditingSPM = true
                            spmFieldFocused = true
                        }
                }
            }
            .padding(.bottom, 20)
            .onChange(of: spmFieldFocused) { _, focused in
                if !focused { commitSPMEdit() }
            }

            Button {
                withAnimation(freqSpring) { isPickingFrequency = true }
            } label: {
                RuntronomeButton(style: .pill(text: alertFrequency.rawValue))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)

            Text("SPM")
                .font(.momoTrust(size: 11, weight: .regular))
                .foregroundColor(Color(white: 0.45))
        }
    }

    private var footerView: some View {
        VStack(spacing: 16) {
            Text("\(totalSteps.formatted(.number)) TOTAL STEPS")
                .font(.momoTrust(size: 11, weight: .regular))
                .foregroundColor(Color(white: 0.45))
                .scaleEffect(isSliderActive ? 0.85 : 1.0)
                .opacity(isSliderActive ? 0.5 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSliderActive)

            HStack(spacing: 0) {
                Button(action: togglePlayback) {
                    RuntronomeButton(style: .circular(systemImage: isPlaying ? "pause.fill" : "play.fill"))
                }
                .buttonStyle(.plain)
                .frame(width: isSliderActive ? 0 : 52, height: 52)
                .clipped()
                .padding(.trailing, isSliderActive ? 0 : 16)

                SPMSlider(value: $spm, range: 0...300, isActive: $isSliderActive)
                    .onChange(of: isSliderActive) { _, active in
                        if !active {
                            syncWidget()
                            if isPlaying { restartMetronome(); updateLiveActivity() }
                        }
                    }
            }
            .padding(.horizontal, isSliderActive ? 40 : 20)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSliderActive)
        }
        .padding(.bottom, 48)
    }

    // MARK: Phase progress UI

    /// Current phase name + countdown/distance + what's next. Falls back to the
    /// plain phase label when no structured plan is loaded.
    @ViewBuilder
    private var phaseHeader: some View {
        if let phase = currentPhase {
            VStack(spacing: 8) {
                Text(phase.title.isEmpty ? "PHASE" : phase.title.uppercased())
                    .font(.momoTrust(size: 12, weight: .regular))
                    .foregroundColor(Color(white: 0.5))
                phaseGoalView(phase)
                if let next = nextPhase {
                    Text("NEXT — \(next.title.isEmpty ? "PHASE" : next.title.uppercased())")
                        .font(.momoTrust(size: 10, weight: .regular))
                        .foregroundColor(Color(white: 0.38))
                }
            }
            .padding(.bottom, 16)
        } else if isGarminConnected {
            Text(phaseLabel)
                .font(.momoTrust(size: 11, weight: .regular))
                .foregroundColor(Color(white: 0.45))
                .padding(.bottom, 6)
        }
    }

    /// Timed phases show a countdown (auto-advances); distance/open phases show
    /// the goal plus a manual NEXT control.
    @ViewBuilder
    private func phaseGoalView(_ phase: WorkoutPhase) -> some View {
        switch phase.goal {
        case .time:
            Text(countdownString)
                .font(.momoTrust(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
        case .distance(let meters):
            HStack(spacing: 12) {
                Text("\(meters) M")
                    .font(.momoTrust(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                nextStepButton
            }
        case .open:
            nextStepButton
        }
    }

    private var nextStepButton: some View {
        Button { advancePhase() } label: {
            HStack(spacing: 5) {
                Text("NEXT").font(.momoTrust(size: 12, weight: .semibold))
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color(white: 0.28)))
        }
        .buttonStyle(.plain)
    }

    // MARK: Frequency spread picker

    private var freqSpring: Animation { .spring(response: 0.42, dampingFraction: 0.82) }
    private var freqPillSpacing: CGFloat { 50 }
    /// Pushes the fan down from screen centre so the selected pill sits roughly
    /// on the frequency button (which lives just below the big SPM number).
    private var freqFanOffset: CGFloat { 88 }

    /// The options live "behind" the button: tapping fans them up/down from the
    /// centre, the selected one staying put. Background dims; content blurs.
    private var frequencyOverlay: some View {
        ZStack {
            Color.black
                .opacity(isPickingFrequency ? 0.3 : 0)
                .ignoresSafeArea()
                .onTapGesture { collapseFrequency() }

            // The fan lives at the button's position (offset below centre) and
            // its options spread out of that point.
            ZStack {
                let selectedIndex = AlertFrequency.allCases.firstIndex(of: alertFrequency) ?? 0
                ForEach(Array(AlertFrequency.allCases.enumerated()), id: \.offset) { index, freq in
                    let spread = CGFloat(index - selectedIndex) * freqPillSpacing
                    freqPill(freq, isSelected: freq == alertFrequency)
                        .offset(y: isPickingFrequency ? spread : 0)
                        .opacity(isPickingFrequency ? 1 : 0)
                }
            }
            .offset(y: freqFanOffset)
        }
        .allowsHitTesting(isPickingFrequency)
    }

    private func freqPill(_ freq: AlertFrequency, isSelected: Bool) -> some View {
        Button { selectFrequency(freq) } label: {
            Text(freq.rawValue)
                .font(.momoTrust(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.28)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white, lineWidth: isSelected ? 1.5 : 0)
                )
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

    /// Seed the metronome from the current phase: label, cadence, and (if timed)
    /// the countdown.
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
    }

    private func advancePhase() {
        guard let plan else { return }
        let next = currentPhaseIndex + 1
        if plan.phases.indices.contains(next) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                currentPhaseIndex = next
            }
            applyCurrentPhase()
        } else if isPlaying {
            togglePlayback()   // workout complete — stop cleanly
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
        applyCurrentPhase()
        syncWidget()
    }

    private func teardown() {
        metronomeTimer?.invalidate()
        clockTimer?.invalidate()
    }

    // MARK: Metronome

    private func togglePlayback() {
        isPlaying ? stopMetronome() : startMetronome()
        isPlaying.toggle()
    }

    private func startMetronome() {
        guard spm > 0 else { return }
        stepCount = 0
        let interval = 60.0 / spm
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            tick()
        }
        startLiveActivity()
    }

    private func stopMetronome() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
        endLiveActivity()
    }

    private func restartMetronome() {
        metronomeTimer?.invalidate()
        guard spm > 0 else { return }
        let interval = 60.0 / spm
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in tick() }
    }

    private func commitSPMEdit() {
        if let parsed = Double(spmInputText) {
            spm = min(max(parsed.rounded(), 0), 300)
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
