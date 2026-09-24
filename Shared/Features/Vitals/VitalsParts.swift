import SwiftUI
import FoundryCore

/// Asleep vs goal, 12 pt ring with the duration in the middle.
struct SleepRing: View {
    var asleep: Int
    var goal: Int
    var diameter: CGFloat = 208
    var showGoal = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    var body: some View {
        let k = diameter / 208
        let target = goal > 0 ? min(1, Double(asleep) / Double(goal)) : 0
        ZStack {
            ProgressRing(progress: shown, lineWidth: 12 * k)
                .frame(width: 196 * k, height: 196 * k)
            Circle().stroke(Palette.surface2, lineWidth: 1.5).frame(width: 144 * k, height: 144 * k)
            VStack(spacing: 2 * k) {
                Image(systemName: "moon")
                    .font(.system(size: 20 * k, weight: .medium))
                    .foregroundStyle(Palette.accent)
                Text(asleep > 0 ? SleepBuilder.formatDuration(minutes: asleep) : "—")
                    .font(FoundryFont.fixed(.condensedBold, size: 48 * k))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if showGoal {
                    Text("OF \(Self.goalText(goal)) GOAL").mono(11, tracking: 0.1).foregroundStyle(Palette.textMuted)
                }
            }
            .padding(.horizontal, 24 * k)
        }
        .frame(width: diameter, height: diameter)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8)) { shown = target }
        }
        .onChange(of: target) { _, new in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5)) { shown = new }
        }
        .accessibilityElement()
        .accessibilityLabel("Sleep last night")
        .accessibilityValue(asleep > 0 ? "\(asleep / 60) hours \(asleep % 60) minutes of a \(Self.goalText(goal).lowercased()) goal" : "No sleep recorded")
    }

    static func goalText(_ goal: Int) -> String {
        goal % 60 == 0 ? "\(goal / 60)H" : "\(goal / 60)H \(goal % 60)M"
    }
}

/// Deep / core / REM / awake proportions with a legend.
struct StageBar: View {
    var sleep: SleepSummary
    var height: CGFloat = 14
    var showLegend = true

    private var segments: [(String, Int, Color)] {
        [("DEEP", sleep.deep, Palette.sleepDeep), ("CORE", sleep.core, Palette.sleepCore),
         ("REM", sleep.rem, Palette.sleepREM), ("AWAKE", sleep.awake, Palette.sleepAwake)]
    }

    var body: some View {
        let total = max(1, sleep.asleep + sleep.awake)
        VStack(spacing: 10) {
            GeometryReader { geo in
                let visible = segments.filter { $0.1 > 0 }
                let gaps = CGFloat(max(visible.count - 1, 0)) * 2
                HStack(spacing: 2) {
                    ForEach(visible, id: \.0) { seg in
                        Rectangle().fill(seg.2)
                            .frame(width: max(2, (geo.size.width - gaps) * CGFloat(seg.1) / CGFloat(total)))
                    }
                }
            }
            .frame(height: height)
            .background(Palette.line)
            .clipShape(RoundedRectangle(cornerRadius: height / 2))
            if showLegend {
                // One row normally; two rows of two at large text sizes.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        ForEach(segments, id: \.0) { seg in
                            legend(seg, dot: false)
                            if seg.0 != "AWAKE" { Spacer(minLength: 0) }
                        }
                    }
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                        GridRow { legend(segments[0]); legend(segments[1]) }
                        GridRow { legend(segments[2]); legend(segments[3]) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sleep stages")
        .accessibilityValue(segments.map { "\($0.0.lowercased()) \($0.1 / 60) hours \($0.1 % 60) minutes" }.joined(separator: ", "))
    }

    /// A color key dot plus `DEEP 1:20`.
    private func legend(_ seg: (String, Int, Color), dot: Bool = true) -> some View {
        HStack(spacing: 6) {
            if dot { Circle().fill(seg.2).frame(width: 7, height: 7) }
            Text("\(seg.0) \(SleepBuilder.formatClock(minutes: seg.1))")
                .mono(11, tracking: 0.06)
                .foregroundStyle(Palette.textMuted)
                .fixedSize()
        }
    }
}

/// `RECOVERY 82% · ×1.2 XP TODAY`.
struct RecoveryPill: View {
    var recovery: Int?
    var height: CGFloat = 48
    var fontSize: CGFloat = 20
    var includeToday = true

    var body: some View {
        let boosted = RecoveryRules.multiplier(for: recovery) > 1
        HStack(spacing: 10) {
            Image(systemName: "bolt").font(.system(size: fontSize * 0.9, weight: .semibold))
            Text(text(boosted: boosted))
                .condensed(fontSize, tracking: 0.06, relativeTo: .headline)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .foregroundStyle(boosted ? Palette.accent : Palette.textMuted)
        .frame(maxWidth: .infinity, minHeight: height)
        .padding(.horizontal, 12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(boosted ? Palette.accent : Palette.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func text(boosted: Bool) -> String {
        guard let recovery else { return "RECOVERY —" }
        if boosted { return "RECOVERY \(recovery)% · ×1.2 XP" + (includeToday ? " TODAY" : "") }
        return "RECOVERY \(recovery)% · NO BONUS"
    }
}

/// Small stat tile (resting heart rate, workouts).
struct StatTile: View {
    var icon: String
    var iconColor: Color
    var customGlyph: Glyph? = nil
    var label: String
    var value: String
    var unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let customGlyph {
                    GlyphView(glyph: customGlyph, size: 16, lineWidth: 2, color: iconColor)
                } else {
                    Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(iconColor)
                }
                Text(label).mono(11, tracking: 0.08).foregroundStyle(Palette.textMuted)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value).condensed(34, tracking: 0).foregroundStyle(Palette.text)
                Text(unit).mono(12, tracking: 0.04).foregroundStyle(Palette.textMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: Metrics.tileRadius)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label.capitalized)
        .accessibilityValue("\(value) \(unit.lowercased())")
    }
}

/// Seven bars of workout minutes, Monday to Sunday.
struct WorkoutBars: View {
    var minutes: [Int]
    var todayIndex: Int
    var height: CGFloat = 78
    var maxBar: CGFloat = 46

    var body: some View {
        let peak = CGFloat(max(minutes.max() ?? 0, 45))
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(minutes.enumerated()), id: \.offset) { i, m in
                VStack(spacing: 6) {
                    Spacer(minLength: 0)
                    if m > 0 {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(i == todayIndex ? Palette.accent : Palette.climbed)
                            .frame(height: max(8, maxBar * CGFloat(m) / peak))
                    } else {
                        RoundedRectangle(cornerRadius: 2).fill(Palette.line).frame(height: 4)
                    }
                    Text(verbatim: DayKeys.weekdayLetters[i])
                        .mono(11, tracking: 0)
                        .foregroundStyle(i == todayIndex ? Palette.text : Palette.textMuted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Workout minutes this week")
        .accessibilityValue(minutes.enumerated().map { "\(DayKeys.weekdayNames[$0.offset]) \($0.element)" }.joined(separator: ", "))
    }
}
