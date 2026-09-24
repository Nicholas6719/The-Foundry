import SwiftUI
import FoundryCore

/// `TONIGHT'S MISSION` card with the round arrow that starts an Island session.
struct MissionCard: View {
    var mission: String
    var compact = false
    var fill: Color = Palette.surface
    var onBegin: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("TONIGHT'S MISSION").mono(11, tracking: 0.12).foregroundStyle(Palette.accent)
                Text(mission)
                    .body(compact ? 17 : 19, weight: .semibold, relativeTo: .headline)
                    .foregroundStyle(Palette.text)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            RoundAccentButton(systemImage: "arrow.right", diameter: compact ? 44 : 48,
                              label: "Begin the mission on the Island", action: onBegin)
        }
        .padding(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 14))
        .card(fill: fill)
    }
}

/// Streak numeral plus the week's seven arrow ticks.
struct StreakRow: View {
    var streak: Int
    var week: [DayMark]

    var body: some View {
        HStack(alignment: .center) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(streak)")
                    .condensed(44, tracking: 0, relativeTo: .largeTitle)
                    .foregroundStyle(Palette.accent)
                Text("DAY STREAK").mono(11, tracking: 0.1).foregroundStyle(Palette.textMuted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(streak) day streak")
            Spacer(minLength: 12)
            WeekArrows(week: week)
                .frame(width: 170, height: 28)
        }
        .padding(.horizontal, 6)
    }
}

/// Seven arrow ticks, Monday to Sunday.
struct WeekArrows: View {
    var week: [DayMark]

    var body: some View {
        Canvas { ctx, size in
            let pitch = (size.width - 24) / 6
            for (i, mark) in week.enumerated() {
                ctx.translateBy(x: CGFloat(i) * pitch, y: 0)
                switch mark {
                case .bullseye:
                    ctx.stroke(SVGPath.path("M4 24L18 4M8 24L18 10"), with: .color(Palette.accent),
                               style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                case .today:
                    ctx.stroke(SVGPath.path("M4 24L18 4"), with: .color(Palette.accent),
                               style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [3, 5]))
                case .missed, .future:
                    ctx.stroke(SVGPath.path("M4 24L18 4"), with: .color(Palette.lineDim),
                               style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 5]))
                }
                ctx.translateBy(x: -CGFloat(i) * pitch, y: 0)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Self.describe(week))
    }

    static func describe(_ week: [DayMark]) -> String {
        let hits = week.filter { $0 == .bullseye }.count
        let todayInProgress = week.contains { if case .today = $0 { true } else { false } }
        let future = week.filter { $0 == .future }.count
        var parts = ["\(hits) of 7 days hit this week"]
        if todayInProgress { parts.append("today in progress") }
        if future > 0 { parts.append("\(future) to come") }
        return parts.joined(separator: ", ")
    }
}

/// Rank chevrons and total XP. Opens Rank.
struct RankChip: View {
    var xp: Int
    var rank: Rank
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Chip {
                GlyphView(glyph: .chevrons, size: 18, lineWidth: 2)
                Text(xp.formatted(.number.grouping(.automatic)))
                    .mono(13, tracking: 0.06)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Rank: \(rank.title.capitalized), \(xp.formatted()) XP")
        .accessibilityHint("Opens Rank")
    }
}
