import SwiftUI
import AudioToolbox
import AVFoundation

struct ContentView: View {
    @State private var locationService = LocationService()

    // Simulated Garmin state — wire up real SDK when available
    @State private var isGarminConnected = true
    @State private var trainingTitle = "Goal Pace Repeats"
    @State private var phaseLabel = "WARM UP"

    @State private var spm: Double = 175
    @State private var isPlaying = false
    @State private var alertFrequency: AlertFrequency = .everyOther
    @State private var totalSteps = 0
    @State private var stepCount = 0
    @State private var metronomeTimer: Timer?
    @State private var currentTime = Date()
    @State private var clockTimer: Timer?
    @State private var hapticTrigger = 0

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

    var body: some View {
        ZStack {
            Color(white: 0.165).ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                Spacer()
                centralView
                Spacer()
                footerView
            }
        }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: hapticTrigger)
        .onAppear { setup() }
        .onDisappear { teardown() }
    }

    // MARK: Subviews

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
                .tracking(0.5)
        }
        .padding(.top, 56)
        .padding(.horizontal, 24)
    }

    private var centralView: some View {
        VStack(spacing: 0) {
            if isGarminConnected {
                Text(phaseLabel)
                    .font(.momoTrust(size: 11, weight: .regular))
                    .foregroundColor(Color(white: 0.45))
                    .tracking(4)
                    .padding(.bottom, 6)
            }

            Text("\(Int(spm))")
                .font(.momoTrust(size: 130, weight: .bold))
                .foregroundColor(.white)
                .contentTransition(.numericText())
                .animation(.snappy, value: Int(spm))
                .padding(.bottom, 20)

            Menu {
                ForEach(AlertFrequency.allCases) { freq in
                    Button(freq.rawValue) { alertFrequency = freq }
                }
            } label: {
                RuntronomeButton(style: .pill(text: alertFrequency.rawValue))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)

            Text("SPM")
                .font(.momoTrust(size: 11, weight: .regular))
                .foregroundColor(Color(white: 0.45))
                .tracking(4)
        }
    }

    private var footerView: some View {
        VStack(spacing: 16) {
            Text("\(totalSteps.formatted(.number)) TOTAL STEPS")
                .font(.momoTrust(size: 11, weight: .regular))
                .foregroundColor(Color(white: 0.45))
                .tracking(2)

            HStack(spacing: 16) {
                Button(action: togglePlayback) {
                    RuntronomeButton(style: .circular(systemImage: isPlaying ? "pause.fill" : "play.fill"))
                }
                .buttonStyle(.plain)

                SPMSlider(value: $spm, range: 0...300)
                    .onChange(of: spm) { _, _ in
                        if isPlaying { restartMetronome() }
                    }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 48)
    }

    // MARK: Setup

    private func setup() {
        // Allow metronome click through silent switch
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)

        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            currentTime = Date()
        }
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
    }

    private func stopMetronome() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
    }

    private func restartMetronome() {
        stopMetronome()
        startMetronome()
    }

    private func tick() {
        totalSteps += 1
        stepCount += 1
        if stepCount % alertFrequency.stepInterval == 0 {
            AudioServicesPlaySystemSound(1057)
            hapticTrigger += 1
        }
    }
}

#Preview {
    ContentView()
}
