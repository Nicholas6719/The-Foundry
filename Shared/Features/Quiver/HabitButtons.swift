import SwiftUI

/// A round habit button: solid when fired, glowing outline when pending.
struct HabitButton: View {
    var name: String
    var glyph: HabitGlyph
    var fired: Bool
    var isAuto: Bool = false
    var size: CGFloat = 64
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: size > 50 ? 8 : 6) {
                ZStack {
                    if fired {
                        Circle().fill(Palette.accent).padding(size / 32)
                        HabitGlyphView(glyph: glyph, size: size * 24 / 64, color: Palette.onAccent)
                    } else {
                        Circle().fill(Palette.surface).padding(size / 32)
                        Circle().stroke(Palette.accent.opacity(0.25), lineWidth: 8).padding(size / 32)
                        Circle().stroke(Palette.accent, lineWidth: 2.5).padding(size / 32)
                        HabitGlyphView(glyph: glyph, size: size * 24 / 64, color: Palette.accent)
                    }
                }
                .frame(width: size, height: size)
                Text(name)
                    .mono(11, tracking: 0.08)
                    .foregroundStyle(fired ? Palette.textMuted : Palette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityValue(fired ? (isAuto ? "Fired automatically" : "Fired") : "Ready to fire")
        .accessibilityHint(fired ? "Double-tap to undo" : "Double-tap to fire")
    }
}

/// Rows of up to four; full rows spread edge to edge, a short last row is centered on the same pitch.
struct HabitRowsLayout: Layout {
    var perRow = 4
    var rowSpacing: CGFloat = 18

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        let rows = rowsOf(subviews)
        let height = rows.reduce(0) { total, row in
            total + (row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0)
        } + CGFloat(max(rows.count - 1, 0)) * rowSpacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rowsOf(subviews)
        let columns = CGFloat(min(perRow, subviews.count))
        guard columns > 0 else { return }
        let pitch = bounds.width / columns
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            let inset = (columns - CGFloat(row.count)) * pitch / 2
            for (i, index) in row.enumerated() {
                let x = bounds.minX + inset + pitch * (CGFloat(i) + 0.5)
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .top,
                                      proposal: ProposedViewSize(width: pitch, height: nil))
            }
            y += rowHeight + rowSpacing
        }
    }

    private func rowsOf(_ subviews: Subviews) -> [[Int]] {
        stride(from: 0, to: subviews.count, by: perRow).map { Array($0..<min($0 + perRow, subviews.count)) }
    }
}

/// Seven small targets for the week.
struct WeekTargets: View {
    var week: [DayMark]
    var todayIndex: Int
    var size: CGFloat = 26
    var showLetters = true
    var cutout: Color = Palette.bg

    var body: some View {
        HStack {
            ForEach(Array(week.enumerated()), id: \.offset) { i, mark in
                VStack(spacing: 6) {
                    MiniTarget(mark: mark, cutout: cutout).frame(width: size, height: size)
                    if showLetters {
                        Text(verbatim: ["M", "T", "W", "T", "F", "S", "S"][i])
                            .mono(11, tracking: 0)
                            .foregroundStyle(i == todayIndex ? Palette.text : Palette.textMuted)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][i])
                .accessibilityValue(Self.describe(mark))
            }
        }
    }

    static func describe(_ mark: DayMark) -> String {
        switch mark {
        case .bullseye: "Bullseye"
        case .today: "In progress"
        case .missed: "Missed"
        case .future: "Upcoming"
        }
    }
}

struct MiniTarget: View {
    var mark: DayMark
    var cutout: Color

    var body: some View {
        GeometryReader { geo in
            let k = geo.size.width / 30
            ZStack {
                switch mark {
                case .bullseye:
                    Circle().fill(Palette.accent).padding(2 * k)
                    Circle().stroke(cutout, lineWidth: 1.5).padding(6.5 * k)
                    Circle().fill(cutout).padding(11.5 * k)
                case .today(let progress):
                    ProgressRing(progress: progress, lineWidth: 3 * k).padding(1.5 * k)
                case .missed:
                    Circle().stroke(Palette.lineDim, lineWidth: 1.5).padding(3 * k)
                case .future:
                    Circle().stroke(Palette.lineDim, style: StrokeStyle(lineWidth: 1.5, dash: [3, 4])).padding(3 * k)
                }
            }
        }
    }
}
