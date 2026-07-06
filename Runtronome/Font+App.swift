import SwiftUI
import UIKit
import CoreText

// MARK: - Font Registration
//
// The only bundled face is Anton (the display/poster font). Everything else is
// SF Pro, the system font — no registration needed for that. Registering here
// picks up any bundled .ttf (currently just Anton) so `.anton(size:)` resolves.

enum AppFonts {
    static func register() {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil)
                      ?? Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts")
        else { return }
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

// MARK: - SwiftUI Font Extension

extension Font {
    /// The app's workhorse sans — SF Pro (system font) at the given size/weight.
    /// Named for its role, not its family, so a later swap stays one place.
    static func appSans(size: CGFloat, weight: UIFont.Weight = .regular) -> Font {
        .system(size: size, weight: Font.Weight(weight))
    }

    /// Anton — heavy condensed display face for poster headlines and big numerals.
    static func anton(size: CGFloat) -> Font {
        .custom("Anton-Regular", size: size)
    }
}

// MARK: - Weight bridge

private extension Font.Weight {
    init(_ weight: UIFont.Weight) {
        switch weight {
        case .ultraLight: self = .ultraLight
        case .thin:       self = .thin
        case .light:      self = .light
        case .regular:    self = .regular
        case .medium:     self = .medium
        case .semibold:   self = .semibold
        case .bold:       self = .bold
        case .heavy:      self = .heavy
        case .black:      self = .black
        default:          self = .regular
        }
    }
}
