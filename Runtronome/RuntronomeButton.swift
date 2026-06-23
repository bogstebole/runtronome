import SwiftUI

/// Reusable styled button label. Use inside `Button` or `Menu` — the caller owns the interaction.
struct RuntronomeButton: View {
    enum Style {
        case circular(systemImage: String)
        case pill(text: String)
        /// Full-width high-contrast call to action (e.g. "Sync", "Save & Start").
        case primary(text: String, systemImage: String? = nil, loading: Bool = false)
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
                .font(.momoTrust(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.28))
                )

        case .primary(let text, let systemImage, let loading):
            HStack(spacing: 10) {
                if loading {
                    SyncSpinner(color: Theme.ctaLabel, size: 18, lineWidth: 2.2)
                } else {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text(text)
                        .font(.momoTrust(size: 15, weight: .semibold))
                }
            }
            .foregroundColor(Theme.ctaLabel)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.ctaFill))
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
