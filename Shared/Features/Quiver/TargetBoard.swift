import SwiftUI

/// One lodged arrow in the 300-point target space: tip position and rotation.
struct ArrowPose {
    var tip: CGPoint
    var degrees: Double

    /// Fire order from the design reference.
    static let all: [ArrowPose] = [
        ArrowPose(tip: CGPoint(x: 130, y: 160), degrees: -30),
        ArrowPose(tip: CGPoint(x: 176, y: 136), degrees: 24),
        ArrowPose(tip: CGPoint(x: 148, y: 186), degrees: 150),
        ArrowPose(tip: CGPoint(x: 165, y: 172), degrees: 100),
        ArrowPose(tip: CGPoint(x: 136, y: 142), degrees: -100),
        ArrowPose(tip: CGPoint(x: 158, y: 150), degrees: 60),
        ArrowPose(tip: CGPoint(x: 140, y: 172), degrees: -140),
        ArrowPose(tip: CGPoint(x: 160, y: 140), degrees: -10)
    ]
}

/// Arrow drawn along −y from its tip, in the 300-point space scaled to the frame.
nonisolated struct ArrowShape: Shape {
    var tip: CGPoint
    var degrees: Double
    var fletching: Bool

    func path(in rect: CGRect) -> Path {
        let k = rect.width / 300
        var p = Path()
        if fletching {
            for y in [-84.0, -96.0] {
                p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: -9, y: y - 13))
                p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: 9, y: y - 13))
            }
        } else {
            p.move(to: .zero)
            p.addLine(to: CGPoint(x: 0, y: -96))
        }
        let t = CGAffineTransform(rotationAngle: degrees * .pi / 180)
            .concatenating(CGAffineTransform(translationX: tip.x, y: tip.y))
            .concatenating(CGAffineTransform(scaleX: k, y: k))
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))
        return p.applying(t)
    }
}

struct LodgedArrow: View {
    var pose: ArrowPose
    var animate: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flight: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            let k = geo.size.width / 300
            let rad = pose.degrees * .pi / 180
            // Tail direction is (sin θ, −cos θ); the arrow slides in along it.
            let back = (1 - flight) * 190 * k
            ZStack {
                ArrowShape(tip: pose.tip, degrees: pose.degrees, fletching: false)
                    .stroke(Palette.accent, style: StrokeStyle(lineWidth: 4 * max(k, 0.8), lineCap: .round))
                ArrowShape(tip: pose.tip, degrees: pose.degrees, fletching: true)
                    .stroke(Palette.accent, style: StrokeStyle(lineWidth: 3 * max(k, 0.8), lineCap: .round))
            }
            .offset(x: sin(rad) * back, y: -cos(rad) * back)
            .opacity(reduceMotion ? Double(flight) : 1)
        }
        .onAppear {
            guard animate else { return }
            flight = 0
            withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.5, dampingFraction: 0.72)) {
                flight = 1
            }
        }
    }
}

/// The target: four rings and a red bull, with one arrow per fired habit.
struct TargetBoard: View {
    var fired: Int
    var total: Int
    /// False on first appearance so existing arrows don't all fly in at once.
    var animateNew: Bool

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let k = size.width / 300
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let rings: [(CGFloat, Color)] = [(140, Palette.surface), (105, Palette.surfaceInset),
                                                 (70, Palette.surface), (35, Palette.surfaceInset)]
                for (r, fill) in rings {
                    let rect = CGRect(x: c.x - r * k, y: c.y - r * k, width: 2 * r * k, height: 2 * r * k)
                    ctx.fill(Path(ellipseIn: rect), with: .color(fill))
                    ctx.stroke(Path(ellipseIn: rect), with: .color(Palette.lineStrong), lineWidth: 2)
                }
                let bull = 12 * k
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - bull, y: c.y - bull, width: bull * 2, height: bull * 2)),
                         with: .color(Palette.inkRed))
            }
            ForEach(0..<min(fired, ArrowPose.all.count), id: \.self) { i in
                LodgedArrow(pose: ArrowPose.all[i], animate: animateNew)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Target")
        .accessibilityValue(total == 0 ? "No habits yet"
            : fired >= total ? "Bullseye, all \(total) arrows lodged" : "\(fired) of \(total) arrows lodged")
    }
}
