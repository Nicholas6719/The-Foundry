import SwiftUI

/// A track plus a clockwise progress arc starting at 12 o'clock.
struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat
    var track: Color = Palette.line
    var tint: Color = Palette.accent

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
}

/// Hand-drawn ellipse around a name: slightly irregular, seeded so it looks the same each time.
nonisolated struct HandCircle: Shape {
    var seed: UInt64
    var progress: CGFloat = 1

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var rng = SeededRandom(seed: seed)
        let cx = rect.midX, cy = rect.midY
        let rx = rect.width / 2, ry = rect.height / 2
        // Four wobble radii around the loop echo the mockup's 46/40/44/38 over 34/38/32/36 blob.
        let wobble = (0..<4).map { _ in 1 + CGFloat(rng.next(in: -0.05...0.05)) }
        let startAngle = CGFloat(rng.next(in: -2.6 ... -2.2))
        let sweep = CGFloat.pi * 2 * (1.06 + CGFloat(rng.next(in: 0...0.05)))
        let steps = 72
        var path = Path()
        let last = Int(CGFloat(steps) * max(0, min(1, progress)))
        guard last > 0 else { return path }
        for i in 0...last {
            let t = CGFloat(i) / CGFloat(steps)
            let a = startAngle + sweep * t
            let q = (a - startAngle) / (CGFloat.pi / 2)
            let k = Int(floor(q)) % 4
            let f = q - floor(q)
            let w = wobble[k] * (1 - f) + wobble[(k + 1) % 4] * f
            let drift = 1 + 0.035 * t // the pen overshoots slightly on the way round
            let p = CGPoint(x: cx + cos(a) * rx * w * drift, y: cy + sin(a) * ry * w * (2 - drift))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }
}

/// Small deterministic PRNG (SplitMix64).
nonisolated struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func nextUInt() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        let unit = Double(nextUInt() >> 11) / Double(1 << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}

extension UUID {
    /// Stable 64-bit seed from a UUID.
    var seed: UInt64 {
        let b = uuid
        return [b.0, b.1, b.2, b.3, b.4, b.5, b.6, b.7].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }
}

/// A dashed circle outline.
struct DashedCircle: View {
    var color: Color = Palette.lineDim
    var lineWidth: CGFloat = 2
    var dash: [CGFloat] = [4, 4]

    var body: some View {
        Circle()
            .inset(by: lineWidth / 2)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, dash: dash))
    }
}
