import SwiftUI

enum Metrics {
    static let screenPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 16
    static let cardRadius: CGFloat = 16
    static let tileRadius: CGFloat = 14
    static let buttonHeight: CGFloat = 52
    static let pillHeight: CGFloat = 44
    static let minTap: CGFloat = 44
}

// MARK: - Cards

struct CardBackground: ViewModifier {
    var radius: CGFloat = Metrics.cardRadius
    var fill: Color = Palette.surface
    var stroke: Color = Palette.line

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(stroke, lineWidth: 1))
    }
}

extension View {
    func card(radius: CGFloat = Metrics.cardRadius, fill: Color = Palette.surface, stroke: Color = Palette.line) -> some View {
        modifier(CardBackground(radius: radius, fill: fill, stroke: stroke))
    }
}

// MARK: - Chip

/// The rounded pill used at the top right of every screen.
struct Chip<Content: View>: View {
    var stroke: Color = Palette.line
    var height: CGFloat = Metrics.pillHeight
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 8) { content }
            .padding(.horizontal, 16)
            .frame(minHeight: height)
            .background(Palette.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(stroke, lineWidth: 1))
            .foregroundStyle(Palette.accent)
    }
}

/// Badge on the left, chip on the right.
struct ScreenHeader<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            leading
            Spacer(minLength: 12)
            trailing
        }
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = Metrics.buttonHeight
    var fontSize: CGFloat = 20

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .condensed(fontSize, tracking: 0.08, relativeTo: .headline)
            .foregroundStyle(Palette.onAccent)
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.horizontal, 16)
            .background(Palette.accent.opacity(configuration.isPressed ? 0.8 : 1),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = Metrics.buttonHeight
    var fontSize: CGFloat = 20
    var tint: Color = Palette.accent
    var stroke: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .condensed(fontSize, tracking: 0.08, relativeTo: .headline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(configuration.isPressed ? 0.05 : 0),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(stroke ?? tint, lineWidth: 1))
            .contentShape(Rectangle())
    }
}

/// Round accent button (arrow, plus).
struct RoundAccentButton: View {
    var systemImage: String
    var diameter: CGFloat = 48
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: diameter * 0.42, weight: .bold))
                .foregroundStyle(Palette.onAccent)
                .frame(width: diameter, height: diameter)
                .background(Palette.accent, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Small circular outlined icon button (back, gear).
struct CircleIconButton: View {
    var systemImage: String
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: Metrics.minTap, height: Metrics.minTap)
                .background(Palette.surface, in: Circle())
                .overlay(Circle().strokeBorder(Palette.line, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Dots

struct SetDot: View {
    var filled: Bool
    var size: CGFloat = 14

    var body: some View {
        ZStack {
            if filled {
                Circle().fill(Palette.accent)
            } else {
                Circle().strokeBorder(Palette.textMuted, lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Section title used in sheets and settings.
struct MonoTitle: View {
    var text: String
    var color: Color = Palette.accent

    var body: some View {
        Text(text).mono(11, tracking: 0.12).foregroundStyle(color)
    }
}

// MARK: - Screen scaffold

/// Standard screen: background, 24 pt sides, scrolls when content does not fit.
struct ScreenScroll<Content: View>: View {
    var background: Color = Palette.bg
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionSpacing) { content }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(background.ignoresSafeArea())
    }
}
