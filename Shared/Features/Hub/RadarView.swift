import SwiftUI
import FoundryCore

enum Station: String, CaseIterable, Identifiable {
    case list, quiver, train, island, vitals
    var id: String { rawValue }

    /// Node centers in the 342-point design space.
    var center: CGPoint {
        switch self {
        case .list: CGPoint(x: 171, y: 47)
        case .quiver: CGPoint(x: 289, y: 133)
        case .train: CGPoint(x: 244, y: 271)
        case .island: CGPoint(x: 98, y: 271)
        case .vitals: CGPoint(x: 53, y: 133)
        }
    }

    var glyph: Glyph {
        switch self {
        case .list: .notebook
        case .quiver: .quiver
        case .train: .ladder
        case .island: .crosshair
        case .vitals: .pulse
        }
    }

    var label: String { rawValue.uppercased() }
}

/// The hub: dotted orbit, five station nodes, and the emblem with today's habit ring.
struct RadarView: View {
    var snapshot: TodaySnapshot
    /// Center disc color (screen background on iPhone, card color on the Mac dashboard).
    var centerFill: Color = Palette.bg
    var hexFill: Color = Palette.surface
    var pulse: Int = 0
    var onSelect: (Station) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = 11
    @State private var pulsing = false

    private static let design: CGFloat = 342

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let k = side / Self.design
            ZStack(alignment: .topLeading) {
                staticLayer(k: k)
                center(k: k)
                ForEach(Station.allCases) { station in
                    node(station, k: k)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: pulse) {
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) { pulsing = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) { pulsing = false }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Foundry hub: five stations around the emblem")
    }

    private func staticLayer(k: CGFloat) -> some View {
        Canvas { ctx, _ in
            ctx.scaleBy(x: k, y: k)
            let c = CGPoint(x: 171, y: 171)
            func ring(_ r: CGFloat) -> Path { Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)) }
            ctx.stroke(ring(160), with: .color(Palette.surface2), lineWidth: 1.5)
            ctx.stroke(ring(124), with: .color(Palette.line), style: StrokeStyle(lineWidth: 1.5, dash: [2, 7]))
            ctx.stroke(ring(84), with: .color(Palette.surface2), lineWidth: 1.5)
            ctx.stroke(SVGPath.path("M171 4v22M171 316v22M4 171h22M316 171h22"), with: .color(Palette.line),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round))
            var spokes = Path()
            for station in Station.allCases {
                spokes.move(to: c)
                spokes.addLine(to: station.center)
            }
            ctx.stroke(spokes, with: .color(Palette.surface2), lineWidth: 2)
        }
        .accessibilityHidden(true)
    }

    private func center(k: CGFloat) -> some View {
        ZStack {
            Circle().fill(centerFill).frame(width: 124 * k, height: 124 * k)
            ProgressRing(progress: snapshot.habitProgress, lineWidth: 5 * k)
                .frame(width: 121 * k, height: 121 * k)
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.6, dampingFraction: 0.8),
                           value: snapshot.habitProgress)
            ZStack {
                Hexagon().fill(hexFill)
                Hexagon().stroke(Palette.accent, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                EmblemFill().fill(Palette.accent)
            }
            .frame(width: 74 * k * 48 / 44, height: 74 * k * 48 / 44)
            .scaleEffect(pulsing ? 1.14 : 1)
        }
        .position(x: 171 * k, y: 171 * k)
        .accessibilityElement()
        .accessibilityLabel("Arrows fired today")
        .accessibilityValue("\(snapshot.habitsDone) of \(snapshot.habitsTotal)")
    }

    private func node(_ station: Station, k: CGFloat) -> some View {
        let p = station.center
        return Button { onSelect(station) } label: {
            VStack(spacing: 0) {
                nodeCircle(station, k: k)
                    .frame(width: 56 * k, height: 56 * k)
                Text(station.label)
                    .font(FoundryFont.fixed(.monoRegular, size: labelSize))
                    .tracking(1)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize()
                    .frame(height: 36 * k)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: 88 * k, height: 92 * k)
        .position(x: p.x * k, y: (p.y + 18) * k)
        .overlay {
            if station == .list, snapshot.dueToday > 0 {
                Circle().fill(Palette.inkRed)
                    .frame(width: 14 * k, height: 14 * k)
                    .position(x: 192 * k, y: 27 * k)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel(accessibilityName(station))
        .accessibilityValue(accessibilityValue(station))
        .accessibilityHint(station == .island ? "Opens the Island" : "Opens this screen")
    }

    @ViewBuilder
    private func nodeCircle(_ station: Station, k: CGFloat) -> some View {
        let glyphSize = 24 * k
        switch style(for: station) {
        case .filled:
            ZStack {
                Circle().fill(Palette.accent)
                GlyphView(glyph: station.glyph, size: glyphSize, lineWidth: 2, color: Palette.onAccent)
            }
        case .outlined:
            ZStack {
                Circle().fill(Palette.surface)
                Circle().inset(by: 1).stroke(Palette.accent, lineWidth: 2)
                GlyphView(glyph: station.glyph, size: glyphSize)
            }
        case .dashed:
            ZStack {
                Circle().fill(Palette.surface)
                DashedCircle(color: Palette.lineDim, lineWidth: 2)
                GlyphView(glyph: station.glyph, size: glyphSize, color: Palette.textMuted)
            }
        case .progress(let value):
            ZStack {
                Circle().fill(Palette.surface)
                ProgressRing(progress: value, lineWidth: 4 * k)
                    .padding(-2 * k)
                    .animation(.easeInOut(duration: 0.4), value: value)
                GlyphView(glyph: station.glyph, size: glyphSize)
            }
        }
    }

    private enum NodeStyle { case filled, outlined, dashed, progress(Double) }

    private func style(for station: Station) -> NodeStyle {
        switch station {
        case .list:
            // Filled when nothing is due today; outlined (with the red dot) while something is.
            return snapshot.dueToday == 0 ? .filled : .outlined
        case .quiver:
            return snapshot.isBullseye ? .filled : .progress(snapshot.habitProgress)
        case .train:
            switch snapshot.train {
            case .done: return .filled
            case .rest: return .dashed
            case .pending: return .outlined
            }
        case .island:
            return snapshot.focusDoneToday > 0 ? .filled : .dashed
        case .vitals:
            return snapshot.vitalsSynced ? .filled : .dashed
        }
    }

    private func accessibilityName(_ station: Station) -> String {
        switch station {
        case .list: "List"
        case .quiver: "Quiver"
        case .train: "Train"
        case .island: "Island"
        case .vitals: "Vitals"
        }
    }

    private func accessibilityValue(_ station: Station) -> String {
        switch station {
        case .list:
            let n = snapshot.openTargets
            return n == 0 ? "All names struck" : n == 1 ? "1 name left" : "\(n) names left"
        case .quiver:
            return snapshot.isBullseye ? "Bullseye" : "\(snapshot.habitsDone) of \(snapshot.habitsTotal) arrows fired"
        case .train:
            switch snapshot.train {
            case .done: return "Session complete"
            case .rest: return "Rest day"
            case .pending: return "\(snapshot.workoutName ?? "Session") not done yet"
            }
        case .island:
            let n = snapshot.focusDoneToday
            return n == 0 ? "No session yet today" : n == 1 ? "1 session held" : "\(n) sessions held"
        case .vitals:
            return snapshot.vitalsSynced ? "Last night's sleep synced" : "No sleep data yet"
        }
    }
}
