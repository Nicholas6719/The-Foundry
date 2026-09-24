import SwiftUI
import FoundryCore

/// The salmon ladder for one lift, in a 190×320 design space.
///
/// Rungs sit 50 points apart with the bar's rung at y = 190. On a climb the bar slides up
/// one rung, then the ladder scrolls so the bar settles back at the same height.
struct LadderView: View {
    var currentRung: Int
    var start: Double
    var step: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var barRung: Double = 1
    @State private var cameraRung: Double = 1
    @State private var ready = false

    var body: some View {
        LadderScene(barRung: barRung, cameraRung: cameraRung, currentRung: currentRung, start: start, step: step)
            .aspectRatio(190 / 320, contentMode: .fit)
            .onAppear {
                barRung = Double(currentRung)
                cameraRung = Double(currentRung)
                ready = true
            }
            .onChange(of: currentRung) { old, new in
                guard ready else { return }
                if reduceMotion || new < old {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        barRung = Double(new)
                        cameraRung = Double(new)
                    }
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { barRung = Double(new) }
                    withAnimation(.easeInOut(duration: 0.5).delay(0.55)) { cameraRung = Double(new) }
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Salmon ladder")
            .accessibilityValue("The bar sits on the \(pounds(currentRung)) pound rung, \(pounds(currentRung + 1)) is next")
    }

    private func pounds(_ rung: Int) -> String {
        LadderRules.format(LadderRules.weight(rung: rung, start: start, step: step))
    }
}

/// Animatable drawing of the ladder so the bar and the scroll interpolate smoothly.
private struct LadderScene: View, Animatable {
    var barRung: Double
    var cameraRung: Double
    var currentRung: Int
    var start: Double
    var step: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(barRung, cameraRung) }
        set {
            barRung = newValue.first
            cameraRung = newValue.second
        }
    }

    private static let barY: CGFloat = 190
    private static let pitch: CGFloat = 50

    var body: some View {
        GeometryReader { geo in
            let k = min(geo.size.width / 190, geo.size.height / 320)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    ctx.scaleBy(x: k, y: k)
                    draw(&ctx)
                }
                ForEach(visibleRungs, id: \.self) { rung in
                    if rung != currentRung {
                        Text(LadderRules.format(LadderRules.weight(rung: rung, start: start, step: step)))
                            .font(FoundryFont.fixed(.monoRegular, size: 12 * k))
                            .foregroundStyle(rung == currentRung + 1 ? Palette.accent : Palette.textMuted)
                            .fixedSize()
                            .position(x: 152 * k, y: y(for: rung) * k)
                            .opacity(fade(y(for: rung)))
                    }
                }
            }
            .frame(width: 190 * k, height: 320 * k)
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var visibleRungs: [Int] {
        let center = Int(cameraRung.rounded())
        return Array(max(1, center - 3)...(center + 4))
    }

    private func y(for rung: Int) -> CGFloat {
        Self.barY - (CGFloat(rung) - CGFloat(cameraRung)) * Self.pitch
    }

    private func fade(_ y: CGFloat) -> Double {
        Double(max(0, min(1, min(y - 8, 316 - y) / 20)))
    }

    private func draw(_ ctx: inout GraphicsContext) {
        ctx.stroke(SVGPath.path("M30 8V316M120 8V316"), with: .color(Palette.lineStrong),
                   style: StrokeStyle(lineWidth: 6, lineCap: .round))
        for rung in visibleRungs where rung != currentRung {
            let y = y(for: rung)
            guard y > 0, y < 320 else { continue }
            var line = Path()
            line.move(to: CGPoint(x: 30, y: y))
            line.addLine(to: CGPoint(x: 120, y: y))
            if rung < currentRung {
                ctx.stroke(line, with: .color(Palette.climbed), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            } else if rung == currentRung + 1 {
                ctx.stroke(line, with: .color(Palette.accent), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                var chevron = Path()
                chevron.move(to: CGPoint(x: 66, y: y - 16))
                chevron.addLine(to: CGPoint(x: 75, y: y - 25))
                chevron.addLine(to: CGPoint(x: 84, y: y - 16))
                ctx.stroke(chevron, with: .color(Palette.accent),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            } else {
                ctx.stroke(line, with: .color(Palette.lineDim), style: StrokeStyle(lineWidth: 3, dash: [3, 5]))
            }
        }
        let bar = Self.barY - (CGFloat(barRung) - CGFloat(cameraRung)) * Self.pitch
        ctx.fill(Path(roundedRect: CGRect(x: 12, y: bar - 8, width: 148, height: 16), cornerRadius: 8), with: .color(Palette.accent))
        ctx.fill(Path(roundedRect: CGRect(x: 6, y: bar - 18, width: 12, height: 36), cornerRadius: 4), with: .color(Palette.text))
        ctx.fill(Path(roundedRect: CGRect(x: 154, y: bar - 18, width: 12, height: 36), cornerRadius: 4), with: .color(Palette.text))
    }
}
