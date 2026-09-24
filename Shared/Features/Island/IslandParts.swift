import SwiftUI

/// The Island ring timer in a 264-point design space.
struct IslandRing<Center: View>: View {
    var progress: Double
    var active: Bool
    var diameter: CGFloat = 264
    var guides = true
    @ViewBuilder var center: Center

    var body: some View {
        let k = diameter / 264
        ZStack {
            Circle().stroke(Palette.line, lineWidth: 8 * k).frame(width: 240 * k, height: 240 * k)
            if guides {
                Circle().stroke(Palette.islandGuide, lineWidth: 1.5).frame(width: 192 * k, height: 192 * k)
                Circle().stroke(Palette.islandGuide, lineWidth: 1.5).frame(width: 144 * k, height: 144 * k)
            }
            // Only the arc and its marker glide between ticks; the time text doesn't crossfade.
            ZStack {
                Circle()
                    .trim(from: 0, to: max(0.0001, progress))
                    .stroke(Palette.accent, style: StrokeStyle(lineWidth: 8 * k, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 240 * k, height: 240 * k)
                    .opacity(active ? 1 : 0)
                if active {
                    let angle = (progress * 360 - 90) * .pi / 180
                    ZStack {
                        Circle().stroke(Palette.accent.opacity(0.3), lineWidth: 3).frame(width: 36 * k, height: 36 * k)
                        Circle().fill(Palette.accent).frame(width: 22 * k, height: 22 * k)
                    }
                    .offset(x: cos(angle) * 120 * k, y: sin(angle) * 120 * k)
                }
            }
            .animation(.linear(duration: 1), value: progress)
            center
        }
        .frame(width: diameter, height: diameter)
    }
}

/// `FOUNDRY FOCUS` pill: on, off, or set up.
struct FocusPill: View {
    var pill: FocusService.Pill
    var compact = false
    var onSetUp: () -> Void

    var body: some View {
        let label = switch pill {
        case .on: compact ? "FOCUS ON" : "FOUNDRY FOCUS"
        case .off: "FOCUS OFF"
        case .setUp: "SET UP FOCUS"
        }
        let color = pill == .on ? Palette.accent : Palette.textMuted
        Button {
            if pill == .setUp { onSetUp() }
        } label: {
            HStack(spacing: compact ? 6 : 8) {
                Image(systemName: "moon").font(.system(size: compact ? 12 : 15, weight: .semibold))
                Text(label).mono(compact ? 11 : 12, tracking: 0.08)
            }
            .foregroundStyle(color)
            .padding(.horizontal, compact ? 12 : 16)
            .frame(minHeight: compact ? 32 : Metrics.pillHeight)
            .background(Palette.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(pill == .on ? Palette.accent : Palette.line, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(pill == .setUp)
        .accessibilityLabel(pill == .on ? "Foundry Focus is on" : pill == .off ? "Foundry Focus is off" : "Set up Foundry Focus")
        .accessibilityAddTraits(pill == .setUp ? .isButton : .isStaticText)
    }
}

/// One of the three honest status rows.
struct IslandStatusRow: View {
    var icon: String
    var text: String
    var tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(text).body(16, weight: .medium).foregroundStyle(Palette.text)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .card(radius: 14)
        .accessibilityElement(children: .combine)
    }
}

/// `mm:ss`.
enum Clock {
    static func text(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

/// The Island's target name, circled in red on dark.
struct IslandTargetName: View {
    var name: String?
    var size: CGFloat = 34
    var seed: UInt64

    var body: some View {
        Text(name ?? "Pick a name")
            .script(size)
            .foregroundStyle(name == nil ? Palette.textMuted : Palette.text)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .overlay {
                HandCircle(seed: seed)
                    .stroke(Palette.inkRed, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
    }
}
