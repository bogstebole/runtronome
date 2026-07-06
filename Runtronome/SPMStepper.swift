import SwiftUI

/// Custom −/+ stepper for assigning a phase's target SPM. Tap to nudge by one;
/// press and hold to accelerate. Shows "—" until the user makes a first touch,
/// which reveals a sensible baseline cadence to adjust from.
struct SPMStepper: View {
    @Binding var value: Int?
    var range: ClosedRange<Int> = 0...300

    /// Cadence revealed on the first interaction with an unset phase.
    private let baseline = 160

    @State private var repeatTimer: Timer?
    /// Tap-to-type state for the centre value. Kept separate from focus so the
    /// TextField exists before focus is requested (see NumberField for why).
    @State private var isEditing = false
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            stepButton(systemImage: "minus", direction: -1)
            valueLabel
            stepButton(systemImage: "plus", direction: +1)
        }
        .sensoryFeedback(.selection, trigger: value)
        .onDisappear(perform: stopRepeating)
    }

    // MARK: Value display (tap to type an exact cadence)

    private var valueLabel: some View {
        VStack(spacing: 1) {
            Group {
                if isEditing {
                    TextField("", text: $text)
                        .font(.anton(size: 24))
                        .foregroundColor(Theme.textPrimary)
                        .tint(Theme.textPrimary)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .focused($focused)
                        .onAppear { DispatchQueue.main.async { focused = true } }
                } else {
                    Text(value.map(String.init) ?? "—")
                        .font(.anton(size: 24))
                        .foregroundColor(value == nil ? Theme.textTertiary : Theme.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.18), value: value)
                }
            }
            .frame(height: 28)

            Text("SPM")
                .font(.momoTrust(size: 9, weight: .regular))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
        }
        .frame(width: 58)
        .contentShape(Rectangle())
        .onTapGesture {
            text = value.map(String.init) ?? ""
            isEditing = true
        }
        .onChange(of: focused) { _, isFocused in
            if isEditing, !isFocused { commitTyped() }
        }
    }

    /// Empty input keeps the current value; typed input is clamped to range.
    private func commitTyped() {
        let digits = text.filter(\.isNumber)
        if !digits.isEmpty {
            value = min(max(Int(digits) ?? range.lowerBound, range.lowerBound), range.upperBound)
        }
        isEditing = false
    }

    // MARK: Step button

    private func stepButton(systemImage: String, direction: Int) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(Theme.textPrimary)
            .frame(width: 40, height: 40)
            .background(Rectangle().fill(Theme.control))
            .contentShape(Rectangle())
            // DragGesture(minimumDistance: 0) gives us press-down + release so we
            // can fire once immediately and then repeat while held.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard repeatTimer == nil else { return }
                        adjust(by: direction)
                        startRepeating(direction: direction)
                    }
                    .onEnded { _ in stopRepeating() }
            )
    }

    // MARK: Adjustment

    private func adjust(by direction: Int) {
        // First touch on an unset phase just reveals the baseline.
        guard let current = value else {
            value = baseline
            return
        }
        value = min(max(current + direction, range.lowerBound), range.upperBound)
    }

    private func startRepeating(direction: Int) {
        // Hold briefly before auto-repeating, then tick quickly.
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { _ in
            repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                adjust(by: direction)
            }
        }
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}
