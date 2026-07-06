import SwiftUI

/// Reusable styled button label. Use inside `Button` or `Menu` — the caller owns the interaction.
struct RuntronomeButton: View {
    enum Style {
        case circular(systemImage: String)
        case pill(text: String)
    }

    var style: Style

    var body: some View {
        switch style {
        case .circular(let image):
            ZStack {
                Circle()
                    .fill(Color(white: 0.32))
                    .frame(width: 52, height: 52)
                Image(systemName: image)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
        case .pill(let text):
            Text(text)
                .font(.momoTrust(size: 12, weight: .bold))
                .tracking(1.5)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Rectangle().fill(Color(white: 0.28)))
        }
    }
}

/// Subtle press feedback shared by tappable cards and CTAs: a quick spring
/// scale-down matching the metronome's existing motion vocabulary.
struct PressableButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
