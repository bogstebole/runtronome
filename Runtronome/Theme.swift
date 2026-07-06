import SwiftUI

// MARK: - Theme
//
// Swiss-poster monochrome system: hierarchy comes from type scale, brightness
// and rules (thick bar + hairline), never from default-iOS tint or rounded
// chrome. All surfaces are flat; all corners are sharp.

enum Theme {
    static let background    = Color(white: 0.165)  // app background
    static let surface       = Color(white: 0.22)   // flat input fields / wells
    static let surfaceRaised = Color(white: 0.28)   // raised chips
    static let control       = Color(white: 0.32)   // steppers / small controls

    static let textPrimary   = Color.white
    static let textSecondary = Color(white: 0.50)
    static let textTertiary  = Color(white: 0.45)

    /// Faded cadence-rail neighbours (±1 / ±2 from the live SPM).
    static let railNear      = Color(white: 0.38)
    static let railFar       = Color(white: 0.28)

    /// Structural rules.
    static let rule          = Color.white          // thick masthead bar
    static let hairline      = Color(white: 0.32)   // 1px separators
    static let stroke        = Color(white: 0.30)   // input borders

    /// High-contrast fill for primary call-to-action buttons.
    static let ctaFill       = Color.white
    static let ctaLabel      = Color(white: 0.08)
    /// Near-black fill for secondary transport buttons (pause / next).
    static let ctaDark       = Color(white: 0.09)

    /// Sharp Swiss corners — everything rectangular.
    static let cornerRadius: CGFloat = 2
}

// MARK: - Shared structural views

/// Thick white masthead bar that tops every screen.
struct MastheadRule: View {
    var body: some View {
        Rectangle().fill(Theme.rule).frame(height: 3)
    }
}

/// 1px separator line.
struct Hairline: View {
    var body: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }
}

/// Small tracked caption used for metadata rows (dates, context, counters).
struct MetaLabel: View {
    let text: String
    var color: Color = Theme.textSecondary

    var body: some View {
        Text(text)
            .font(.appSans(size: 11, weight: .regular))
            .tracking(1.2)
            .foregroundColor(color)
    }
}
