import SwiftUI

/// The app's single button component. Use it everywhere a tappable CTA is needed
/// so every button looks the same.
///
/// - `.primary`: solid white rectangle, near-black label.
/// - `.secondary`: near-black rectangle, white label.
/// - `.outline`: hairline-bordered rectangle, muted label.
///
/// All sharp-cornered (Swiss poster). Sizes: `.large` (full-width CTA) and
/// `.compact` (inline, hugs its label).
///
/// Usage: `Button("Save") { … }.buttonStyle(.app(.primary))`
struct AppButtonStyle: ButtonStyle {
    enum Variant { case primary, secondary, outline }
    enum Size { case large, compact }

    var variant: Variant = .primary
    var size: Size = .large

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.appSans(size: size == .large ? 14 : 12, weight: .bold))
            .tracking(1.5)
            .foregroundColor(labelColor)
            .padding(.horizontal, size == .large ? 24 : 16)
            .frame(height: size == .large ? 60 : 40)
            .frame(maxWidth: size == .large ? .infinity : nil)
            .background(Rectangle().fill(fillColor))
            .overlay(
                Rectangle().strokeBorder(
                    variant == .outline ? Theme.hairline : .clear,
                    lineWidth: 1
                )
            )
            .contentShape(Rectangle())
            .scaleEffect(pressed ? 0.98 : 1)
            .opacity(pressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pressed)
    }

    private var fillColor: Color {
        switch variant {
        case .primary:   return Theme.ctaFill
        case .secondary: return Theme.ctaDark
        case .outline:   return .clear
        }
    }

    private var labelColor: Color {
        switch variant {
        case .primary:   return Theme.ctaLabel
        case .secondary: return .white
        case .outline:   return Theme.textSecondary
        }
    }
}

extension ButtonStyle where Self == AppButtonStyle {
    /// `.buttonStyle(.app(.primary))` / `.buttonStyle(.app(.secondary, .compact))`
    static func app(_ variant: AppButtonStyle.Variant, _ size: AppButtonStyle.Size = .large) -> AppButtonStyle {
        AppButtonStyle(variant: variant, size: size)
    }
}
