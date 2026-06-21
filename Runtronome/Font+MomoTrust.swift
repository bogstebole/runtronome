import SwiftUI
import UIKit
import CoreText

// MARK: - Font Registration

enum MomoTrustFont {
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
    /// Momo Trust Sans at the given size and weight via variable font wght axis.
    static func momoTrust(size: CGFloat, weight: UIFont.Weight = .regular) -> Font {
        Font(UIFont.momoTrust(size: size, weight: weight))
    }
}

// MARK: - UIFont Extension

extension UIFont {
    static func momoTrust(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let variation: [NSNumber: NSNumber] = [
            // wght axis tag: 0x77676874 = 2003265652
            NSNumber(value: 2003265652): NSNumber(value: weight.wghtAxisValue)
        ]
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: "MomoTrustSans-Regular",
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variation
        ])
        return UIFont(descriptor: descriptor, size: size)
    }
}

private extension UIFont.Weight {
    var wghtAxisValue: Double {
        switch self {
        case .ultraLight: return 100
        case .thin:       return 200
        case .light:      return 300
        case .regular:    return 400
        case .medium:     return 500
        case .semibold:   return 600
        case .bold:       return 700
        case .heavy:      return 800
        case .black:      return 900
        default:          return 400
        }
    }
}
