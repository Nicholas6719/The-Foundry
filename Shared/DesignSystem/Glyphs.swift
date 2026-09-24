import SwiftUI

/// The custom 24-grid glyphs. Utilities use SF Symbols instead.
enum Glyph: String, CaseIterable {
    case emblem, notebook, quiver, ladder, crosshair, pulse, chevrons, dumbbell, check
    case arrowUpRight, chevronUp, wave

    var shape: GridShape {
        switch self {
        case .emblem: GridShape(d: "M12 3l7 9h-4.5v9h-5v-9H5z")
        case .notebook: GridShape(d: "M9 3v18M12 8h4M12 12h4", rects: [(CGRect(x: 5, y: 3, width: 14, height: 18), 2)])
        case .quiver: GridShape(d: "M6 20L18 8M9 20L21 8M3 17L15 5")
        case .ladder: GridShape(d: "M8 3v18M16 3v18M8 7h8M8 12h8M8 17h8")
        case .crosshair: GridShape(d: "M12 2v4M12 18v4M2 12h4M18 12h4", circles: [(12, 12, 7)])
        case .pulse: GridShape(d: "M3 12h4l2-5 4 10 2-5h6")
        case .chevrons: GridShape(d: "M6 11l6-6 6 6M6 18l6-6 6 6")
        case .dumbbell: GridShape(d: "M6 8v8M18 8v8M3 10v4M21 10v4M6 12h12")
        case .check: GridShape(d: "M5 12.5l4.5 4.5L19 7")
        case .arrowUpRight: GridShape(d: "M5 19L19 5M19 5h-6M19 5v6")
        case .chevronUp: GridShape(d: "M6 15l6-6 6 6")
        case .wave: GridShape(d: "M3 14c3-2 5 2 8 0s5 2 8 0 3 2 3 0")
        }
    }
}

/// A stroked glyph at a given point size.
struct GlyphView: View {
    var glyph: Glyph
    var size: CGFloat = 24
    var lineWidth: CGFloat = 1.75
    var color: Color = Palette.accent

    var body: some View {
        glyph.shape
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Solid arrowhead emblem (the 48-grid `M24 12l9 12h-5v12h-8V24h-5z`).
nonisolated struct EmblemFill: Shape {
    func path(in rect: CGRect) -> Path {
        GridShape(d: "M24 12l9 12h-5v12h-8V24h-5z", grid: 48).path(in: rect)
    }
}

/// The badge hexagon on a 48 grid.
nonisolated struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        GridShape(d: "M24 2L43 13L43 35L24 46L5 35L5 13Z", grid: 48).path(in: rect)
    }
}

/// Hexagon badge: `surface` fill, 2 pt accent stroke, glyph centered.
struct HexBadge: View {
    enum Content { case glyph(Glyph), emblem }
    var content: Content
    var size: CGFloat = 48
    var fill: Color = Palette.surface
    var label: String

    var body: some View {
        ZStack {
            Hexagon().fill(fill)
            Hexagon().stroke(Palette.accent, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            switch content {
            case .glyph(let glyph):
                GlyphView(glyph: glyph, size: size / 2)
            case .emblem:
                EmblemFill().fill(Palette.accent)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isImage)
    }
}

/// Habit icons: a fixed set of eight.
enum HabitGlyph: String, CaseIterable, Identifiable {
    case dumbbell, fork, book, moon, drop, walk, pen, heart

    var id: String { rawValue }

    var name: String {
        switch self {
        case .dumbbell: "Dumbbell"
        case .fork: "Fork and knife"
        case .book: "Book"
        case .moon: "Moon"
        case .drop: "Water"
        case .walk: "Walk"
        case .pen: "Pen"
        case .heart: "Heart"
        }
    }

    var symbol: String? {
        switch self {
        case .dumbbell: nil
        case .fork: "fork.knife"
        case .book: "book"
        case .moon: "moon"
        case .drop: "drop"
        case .walk: "figure.walk"
        case .pen: "pencil"
        case .heart: "heart"
        }
    }
}

struct HabitGlyphView: View {
    var glyph: HabitGlyph
    var size: CGFloat
    var color: Color

    var body: some View {
        if let symbol = glyph.symbol {
            Image(systemName: symbol)
                .font(.system(size: size * 0.78, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            GlyphView(glyph: .dumbbell, size: size, lineWidth: 2.25, color: color)
        }
    }
}
