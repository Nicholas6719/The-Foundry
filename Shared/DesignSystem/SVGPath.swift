import SwiftUI

/// Parses the small subset of SVG path data used by Foundry glyphs:
/// M, L, H, V, C, S, Z (absolute and relative). Coordinates stay in design space.
nonisolated enum SVGPath {
    static func path(_ d: String) -> Path {
        var tokens = Tokenizer(d)
        var path = Path()
        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastControl: CGPoint?
        var command: Character = "M"

        while let next = tokens.peek() {
            if case .command(let c) = next {
                command = c
                _ = tokens.next()
                if c == "Z" || c == "z" {
                    path.closeSubpath()
                    current = start
                    lastControl = nil
                    continue
                }
            }
            let relative = command.isLowercase
            func point() -> CGPoint? {
                guard let x = tokens.number(), let y = tokens.number() else { return nil }
                return relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
            }
            switch command.uppercased().first {
            case "M":
                guard let p = point() else { return path }
                path.move(to: p)
                current = p
                start = p
                lastControl = nil
                command = relative ? "l" : "L" // implicit lineto after moveto
            case "L":
                guard let p = point() else { return path }
                path.addLine(to: p)
                current = p
                lastControl = nil
            case "H":
                guard let x = tokens.number() else { return path }
                current = CGPoint(x: relative ? current.x + x : x, y: current.y)
                path.addLine(to: current)
                lastControl = nil
            case "V":
                guard let y = tokens.number() else { return path }
                current = CGPoint(x: current.x, y: relative ? current.y + y : y)
                path.addLine(to: current)
                lastControl = nil
            case "C":
                guard let c1 = point(), let c2 = point(), let p = point() else { return path }
                path.addCurve(to: p, control1: c1, control2: c2)
                lastControl = c2
                current = p
            case "S":
                let c1 = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                guard let c2 = point(), let p = point() else { return path }
                path.addCurve(to: p, control1: c1, control2: c2)
                lastControl = c2
                current = p
            default:
                return path
            }
        }
        return path
    }

    private enum Token { case command(Character), number(CGFloat) }

    private struct Tokenizer {
        private var tokens: [Token] = []
        private var index = 0

        init(_ d: String) {
            var buffer = ""
            func flush() {
                if let v = Double(buffer) { tokens.append(.number(CGFloat(v))) }
                buffer = ""
            }
            for ch in d {
                if ch.isLetter && ch != "e" {
                    flush()
                    tokens.append(.command(ch))
                } else if ch == "-" && !buffer.isEmpty && buffer.last != "e" {
                    flush()
                    buffer = "-"
                } else if ch == "." && buffer.contains(".") {
                    flush()
                    buffer = "."
                } else if ch == " " || ch == "," || ch == "\n" {
                    flush()
                } else {
                    buffer.append(ch)
                }
            }
            flush()
        }

        func peek() -> Token? { index < tokens.count ? tokens[index] : nil }

        mutating func next() -> Token? {
            defer { index += 1 }
            return peek()
        }

        mutating func number() -> CGFloat? {
            guard case .number(let v)? = peek() else { return nil }
            index += 1
            return v
        }
    }
}

/// A shape drawn from SVG path data on a square design grid, scaled to fit its frame.
nonisolated struct GridShape: Shape {
    var d: String
    var grid: CGFloat = 24
    var circles: [(CGFloat, CGFloat, CGFloat)] = []
    var rects: [(CGRect, CGFloat)] = []

    func path(in rect: CGRect) -> Path {
        var p = SVGPath.path(d)
        for (cx, cy, r) in circles {
            p.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        }
        for (r, radius) in rects {
            p.addRoundedRect(in: r, cornerSize: CGSize(width: radius, height: radius))
        }
        let scale = min(rect.width, rect.height) / grid
        let dx = rect.minX + (rect.width - grid * scale) / 2
        let dy = rect.minY + (rect.height - grid * scale) / 2
        return p.applying(CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: dx, ty: dy))
    }
}
