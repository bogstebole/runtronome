import SwiftUI
import AudioToolbox
import AVFoundation

// MARK: - Alert Frequency

enum AlertFrequency: String, CaseIterable, Identifiable {
    case everyStep   = "EVERY STEP"
    case everyOther  = "EVERY OTHER"
    case every3rd    = "EVERY 3RD"
    case every4th    = "EVERY 4TH"
    case every5th    = "EVERY 5TH"
    case every6th    = "EVERY 6TH"

    var id: String { rawValue }

    var stepInterval: Int {
        switch self {
        case .everyStep:  return 1
        case .everyOther: return 2
        case .every3rd:   return 3
        case .every4th:   return 4
        case .every5th:   return 5
        case .every6th:   return 6
        }
    }
}

// MARK: - Alert Frequency Button

struct AlertFrequencyButton: View {
    @Binding var selection: AlertFrequency

    var body: some View {
        Menu {
            ForEach(AlertFrequency.allCases) { freq in
                Button(freq.rawValue) { selection = freq }
            }
        } label: {
            Text(selection.rawValue)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.28))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Play/Pause Button

struct PlayPauseButton: View {
    var isPlaying: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(white: 0.32))
                    .frame(width: 52, height: 52)
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .offset(x: isPlaying ? 0 : 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SPM Slider

struct SPMSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let fillW = w * max(progress, 0)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(white: 0.22))
                    .frame(height: 40)

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(white: 0.38))
                    .frame(width: max(fillW, 8), height: 40)

                // Tick marks inside the filled portion
                HStack(spacing: 0) {
                    ForEach(0..<22, id: \.self) { _ in
                        Capsule()
                            .fill(Color(white: 0.58))
                            .frame(width: 1.5, height: 14)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: max(fillW, 8), height: 40)
                .clipped()
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let pct = min(max(Double(drag.location.x / w), 0), 1)
                        value = (range.lowerBound + pct * (range.upperBound - range.lowerBound)).rounded()
                    }
            )
        }
        .frame(height: 40)
    }
}

// MARK: - Content View

struct ContentView: View {
    // Simulated Garmin state — replace with real SDK in future
    @State private var isGarminConnected = true

    @State private var spm: Double = 175
    @State private var isPlaying = false
    @State private var alertFrequency: AlertFrequency = .everyOther
    @State private var totalSteps = 0
    @State private var stepCount = 0
    @State private var metronomeTimer: Timer?
    @State private var currentTime = Date()
    @State private var clockTimer: Timer?
    @State private var hapticTrigger = 0

    // Simulated Garmin data — replace with real values from SDK
    private let location      = "BELGRADE"
    private let temperature   = "21°"
    private let trainingTitle = "Goal Pace Repeats"
    private let phaseLabel    = "WARM UP"

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()
    private static let dayDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"; return f
    }()

    private var timeString: String {
        ContentView.timeFormatter.string(from: currentTime)
    }
    private var dayDateString: String {
        ContentView.dayDateFormatter.string(from: currentTime).uppercased()
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
        .onAppear { setupTimers() }
        .onDisappear { teardown() }
    }

    // MARK: Subviews

    private var headerView: some View {
        VStack(spacing: 6) {
            if isGarminConnected {
                Text(trainingTitle)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
            Text("\(location)  –  \(temperature)  –  \(timeString)  –  \(dayDateString)")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
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
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(white: 0.45))
                    .tracking(4)
                    .padding(.bottom, 6)
            }

            Text("\(Int(spm))")
                .font(.system(size: 130, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .contentTransition(.numericText())
                .animation(.snappy, value: Int(spm))
                .padding(.bottom, 20)

            AlertFrequencyButton(selection: $alertFrequency)
                .padding(.bottom, 12)

            Text("SPM")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(Color(white: 0.45))
                .tracking(4)
        }
    }

    private var footerView: some View {
        VStack(spacing: 16) {
            Text("\(totalSteps.formatted(.number)) TOTAL STEPS")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(Color(white: 0.45))
                .tracking(2)

            HStack(spacing: 16) {
                PlayPauseButton(isPlaying: isPlaying, action: togglePlayback)

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

    private func setupTimers() {
        // Allow metronome click to play through the silent switch
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
