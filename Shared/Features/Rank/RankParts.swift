import SwiftUI
import FoundryCore

/// Large emblem with the XP progress ring.
struct RankEmblem: View {
    var fraction: Double
    var diameter: CGFloat = 132

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    var body: some View {
        let k = diameter / 132
        ZStack {
            ProgressRing(progress: shown, lineWidth: 6 * k).frame(width: 130 * k, height: 130 * k)
            ZStack {
                Hexagon().fill(Palette.surface)
                Hexagon().stroke(Palette.accent, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                EmblemFill().fill(Palette.accent).scaleEffect(1.3).offset(y: -2 * k)
            }
            .frame(width: 85 * k, height: 85 * k)
            .offset(y: 3 * k)
        }
        .frame(width: diameter, height: diameter)
        .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.9)) { shown = fraction } }
        .onChange(of: fraction) { _, new in withAnimation(.easeOut(duration: 0.5)) { shown = new } }
        .accessibilityHidden(true)
    }
}

/// Castaway → Vigilante → Hood → Green Arrow.
struct RankPath: View {
    var current: Rank

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Rank.allCases, id: \.self) { rank in
                VStack(spacing: 8) {
                    node(rank).frame(width: 56, height: 56)
                    Text(rank.shortTitle)
                        .mono(11, tracking: 0.06)
                        .foregroundStyle(rank == current ? Palette.accent : Palette.textMuted)
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(rank.title.capitalized)
                .accessibilityValue(rank < current ? "Reached" : rank == current ? "Current rank" : "Locked, \(rank.threshold.formatted()) XP")
            }
        }
        .background(alignment: .top) {
            GeometryReader { geo in
                let pitch = geo.size.width / 4
                let start = pitch / 2
                let span = pitch * 3
                let done = pitch * CGFloat(current.rawValue)
                ZStack(alignment: .leading) {
                    Rectangle().fill(Palette.line).frame(width: span, height: 3)
                    Rectangle().fill(Palette.accent).frame(width: done, height: 3)
                }
                .offset(x: start, y: 27)
            }
        }
    }

    @ViewBuilder
    private func node(_ rank: Rank) -> some View {
        if rank < current {
            ZStack {
                Circle().fill(Palette.accent).padding(2)
                rankGlyph(rank).stroke(Palette.onAccent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 26, height: 26)
            }
        } else if rank == current {
            ZStack {
                Circle().fill(Palette.surface).padding(2)
                Circle().stroke(Palette.accent.opacity(0.25), lineWidth: 8).padding(2)
                Circle().stroke(Palette.accent, lineWidth: 2.5).padding(2)
                rankGlyph(rank).stroke(Palette.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 26, height: 26)
            }
        } else {
            ZStack {
                Circle().fill(Palette.surface).padding(2)
                Circle().stroke(Palette.lineDim, lineWidth: 2).padding(2)
                Image(systemName: "lock").font(.system(size: 18, weight: .medium)).foregroundStyle(Palette.textMuted)
            }
        }
    }

    private func rankGlyph(_ rank: Rank) -> GridShape {
        switch rank {
        case .castaway: Glyph.wave.shape
        case .vigilante: GridShape(d: "M5 14l7-8 7 8M5 20l7-8 7 8")
        case .hood: GridShape(d: "M12 3C7 3 4 8 4 14v6h16v-6c0-6-3-11-8-11zM9 20v-5c0-1.7 1.3-3 3-3s3 1.3 3 3v5")
        case .greenArrow: Glyph.emblem.shape
        }
    }
}

/// One medal: accent ring when earned, dashed and dim when locked.
struct MedalBadge: View {
    var medal: MedalID
    var earned: Bool
    var size: CGFloat = 64

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if earned {
                    Circle().fill(Palette.surface2)
                    Circle().inset(by: 1).stroke(Palette.accent, lineWidth: 2)
                } else {
                    Circle().fill(Palette.surface)
                    DashedCircle(color: Palette.lineDim, lineWidth: 2)
                }
                medalGlyph
            }
            .frame(width: size, height: size)
            Text(medal.title)
                .mono(11, tracking: 0.06)
                .foregroundStyle(earned ? Palette.text : Palette.textMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(medal.title.capitalized)
        .accessibilityValue(earned ? "Earned" : "Locked. \(medal.rule)")
    }

    @ViewBuilder
    private var medalGlyph: some View {
        let color = earned ? Palette.accent : Palette.textMuted
        let g = size * 24 / 64
        switch medal {
        case .firstBullseye:
            ZStack {
                Circle().stroke(color, lineWidth: 2.5).frame(width: size / 2, height: size / 2)
                Circle().fill(earned ? Palette.inkRed : Palette.textMuted).frame(width: size * 10 / 64, height: size * 10 / 64)
            }
        case .sevenStraight: GlyphView(glyph: .quiver, size: g, lineWidth: 2.25, color: color)
        case .rungFour: GlyphView(glyph: .ladder, size: g, lineWidth: 2.25, color: color)
        case .ironSleeper:
            Image(systemName: "moon").font(.system(size: g * 0.85, weight: .semibold)).foregroundStyle(color)
        case .deepFocus: GlyphView(glyph: .crosshair, size: g, lineWidth: 2, color: color)
        case .tenStruck: GlyphView(glyph: .notebook, size: g, lineWidth: 2, color: color)
        }
    }
}

/// Brief full-width banner for a rank-up or medal.
struct CelebrationOverlay: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let current = env.celebrations.current
        ZStack {
            if let current {
                HStack(spacing: 14) {
                    HexBadge(content: .emblem, size: 44, label: "")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(current.eyebrow).mono(11, tracking: 0.14).foregroundStyle(Palette.accent)
                        Text(current.title).condensed(28, tracking: 0.06).foregroundStyle(Palette.text)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.accent, lineWidth: 1.5))
                .shadow(color: Palette.shadow, radius: 20, y: 8)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .onTapGesture { env.celebrations.dismissCurrent() }
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isStaticText)
                .onAppear {
                    #if os(iOS)
                    UIAccessibility.post(notification: .announcement, argument: "\(current.eyebrow.capitalized): \(current.title.capitalized)")
                    #endif
                }
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.8), value: current)
    }
}
