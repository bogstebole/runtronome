import SwiftUI

/// Custom indeterminate spinner — a single rotating arc. Used in place of the
/// system `ProgressView` to keep the app free of default iOS chrome.
struct SyncSpinner: View {
    var color: Color = .white
    var size: CGFloat = 24
    var lineWidth: CGFloat = 2.5

    @State private var isSpinning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.22)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: isSpinning)
            .onAppear { isSpinning = true }
    }
}
