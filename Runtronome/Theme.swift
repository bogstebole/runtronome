import SwiftUI

// MARK: - Theme
//
// Central palette for the workout-sync flow so the new screens stay in lockstep
// with the existing metronome (which uses the same `Color(white:)` values
// inline). Monochrome by design — hierarchy comes from brightness, never from
// default-iOS tint.

enum Theme {
    static let background    = Color(white: 0.165)  // app background
    static let surface       = Color(white: 0.22)   // cards
    static let surfaceRaised = Color(white: 0.28)   // pills / raised chips
    static let control       = Color(white: 0.32)   // circular controls
    static let stroke        = Color(white: 0.30)   // hairline borders

    static let textPrimary   = Color.white
    static let textSecondary = Color(white: 0.50)
    static let textTertiary  = Color(white: 0.45)

    /// High-contrast fill for primary call-to-action buttons.
    static let ctaFill       = Color(white: 0.92)
    static let ctaLabel      = Color(white: 0.12)
}
