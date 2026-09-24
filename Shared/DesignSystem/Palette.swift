import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The Foundry color tokens. The only place hex values live.
///
/// `nonisolated` because SwiftUI resolves dynamic colors on its background render thread;
/// a main-actor provider closure traps there.
nonisolated enum Palette {
    static let bg = Color(hex: 0x08120D)
    static let bgDeep = Color(hex: 0x050D09)
    static let surface = Color(hex: 0x0F1D15)
    static let surface2 = Color(hex: 0x16281D)
    static let surfaceInset = Color(hex: 0x13241A)
    static let islandGuide = Color(hex: 0x12241A)
    static let tabBar = Color(hex: 0x0B1810)
    static let line = dynamic(0x1F3A2A, high: 0x3A5646)
    static let lineStrong = dynamic(0x2B4536, high: 0x4E6C5B)
    static let lineDim = dynamic(0x3A5646, high: 0x6B8A78)
    static let text = Color(hex: 0xE9F1EA)
    static let textMuted = dynamic(0x93A89A, high: 0xC2D3C7)
    static let tabInactive = dynamic(0x8FA596, high: 0xC2D3C7)
    static let accent = Color(hex: 0x62C47F)
    static let onAccent = Color(hex: 0x07110C)
    static let climbed = Color(hex: 0x2C5A3F)
    static let inkRed = Color(hex: 0xE0616D)

    // Notebook paper
    static let paper = Color(hex: 0xE9E3CF)
    static let ink = Color(hex: 0x1A2018)
    static let inkFaded = Color(hex: 0x6B6F60)
    static let inkRedPaper = Color(hex: 0xB3202E)
    static let inkMuted = Color(hex: 0x4A5044)
    static let paperRule = Color(red: 60 / 255, green: 80 / 255, blue: 60 / 255).opacity(0.25)

    // Sleep stages
    static let sleepDeep = Color(hex: 0x1D5A3A)
    static let sleepCore = Color(hex: 0x3F9A62)
    static let sleepREM = Color(hex: 0x9BE3B4)
    static let sleepAwake = Color(hex: 0xE0616D)

    static let shadow = Color.black.opacity(0.5)

    /// A color that brightens when Increase Contrast is on.
    private static func dynamic(_ normal: UInt32, high: UInt32) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            traits.accessibilityContrast == .high ? UIColor(hex: high) : UIColor(hex: normal)
        })
        #else
        return Color(nsColor: NSColor(name: nil) { appearance in
            let isHigh = appearance.name == .accessibilityHighContrastDarkAqua
                || appearance.name == .accessibilityHighContrastAqua
            return NSColor(hex: isHigh ? high : normal)
        })
        #endif
    }
}

extension Color {
    nonisolated init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

#if canImport(UIKit)
extension UIColor {
    nonisolated convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
#else
extension NSColor {
    nonisolated convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
#endif
