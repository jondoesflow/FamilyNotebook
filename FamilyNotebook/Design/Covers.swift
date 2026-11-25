import SwiftUI
import UIKit

/// Illustrated covers, drawn in code so they're crisp at any size and cost nothing to sync.
enum CoverStyle: String, CaseIterable, Identifiable {
    case midnight, lemons, monstera, blush, waves, rainbow, map, forest
    case sunset, watermelon, terrazzo, blossom, kraft, sage, clay, ink
    case photo

    var id: String { rawValue }

    static var illustrated: [CoverStyle] { allCases.filter { $0 != .photo } }

    var name: String {
        switch self {
        case .midnight: "Midnight"
        case .lemons: "Lemons"
        case .monstera: "Monstera"
        case .blush: "Blush"
        case .waves: "Waves"
        case .rainbow: "Rainbow"
        case .map: "Map"
        case .forest: "Forest"
        case .sunset: "Sunset"
        case .watermelon: "Summer"
        case .terrazzo: "Terrazzo"
        case .blossom: "Blossom"
        case .kraft: "Kraft"
        case .sage: "Sage"
        case .clay: "Clay"
        case .ink: "Ink"
        case .photo: "Photo"
        }
    }

    /// Dominant colour (used for tints, the spine label and the journal/trip headers).
    var base: Color {
        switch self {
        case .midnight: Color(hex: 0x1D2B5C)
        case .lemons: Color(hex: 0x2F5D8A)
        case .monstera: Color(hex: 0xF1ECDD)
        case .blush: Color(hex: 0xF4C6D7)
        case .waves: Color(hex: 0x24396B)
        case .rainbow: Color(hex: 0xE9C46A)
        case .map: Color(hex: 0xA9D6E5)
        case .forest: Color(hex: 0x2D5A45)
        case .sunset: Color(hex: 0xF08A5D)
        case .watermelon: Color(hex: 0xBFE6CF)
        case .terrazzo: Color(hex: 0xF3EDE4)
        case .blossom: Color(hex: 0xE8B4B8)
        case .kraft: Color(hex: 0xC9A27A)
        case .sage: Color(hex: 0x9CB59A)
        case .clay: Color(hex: 0xC2725A)
        case .ink: Color(hex: 0x2B2D33)
        case .photo: Color(hex: 0x8A8378)
        }
    }

    var isDark: Bool {
        switch self {
        case .midnight, .lemons, .waves, .forest, .clay, .ink, .photo: true
        default: false
        }
    }
}

// MARK: - Seeded randomness so patterns are stable

struct SeededRandom {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z = z ^ (z >> 31)
        return Double(z % 10_000_000) / 10_000_000
    }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * next() }
}

// MARK: - Art

struct CoverArt: View {
    var style: CoverStyle
    var photo: Data?

    var body: some View {
        switch style {
        case .blush:
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.6, 0.45], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ], colors: [
                Color(hex: 0xFBE3EC), Color(hex: 0xF4C6D7), Color(hex: 0xE9D7F5),
                Color(hex: 0xF7B9CF), Color(hex: 0xFFF1F4), Color(hex: 0xD9C4F2),
                Color(hex: 0xF2D4E6), Color(hex: 0xF9C9D9), Color(hex: 0xEAD9F7),
            ])
        case .photo:
            if let photo, let image = UIImage(data: photo) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Color(hex: 0xA8A196), Color(hex: 0x6F685E)], startPoint: .top, endPoint: .bottom)
            }
        default:
            Canvas { ctx, size in
                CoverPainter.paint(style, in: &ctx, size: size)
            }
        }
    }
}

enum CoverPainter {
    static func paint(_ style: CoverStyle, in ctx: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        let rect = CGRect(origin: .zero, size: size)
        var rng = SeededRandom(UInt64(abs(style.rawValue.hashValueStable)))

        func fill(_ path: Path, _ color: Color) { ctx.fill(path, with: .color(color)) }
        func circle(_ x: Double, _ y: Double, _ r: Double) -> Path {
            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }

        switch style {
        case .midnight:
            ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: [Color(hex: 0x0F1636), Color(hex: 0x24397A)]),
                                                     startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            for _ in 0..<70 {
                let r = rng.range(0.4, 1.3) * w / 160
                fill(circle(rng.next() * w, rng.next() * h * 0.7, r), .white.opacity(rng.range(0.4, 1)))
            }
            let mr = w * 0.12
            fill(circle(w * 0.68, h * 0.24, mr * 2.2), Color(hex: 0xFFF6D5, opacity: 0.08))
            fill(circle(w * 0.68, h * 0.24, mr), Color(hex: 0xFFF3C4))
            fill(circle(w * 0.64, h * 0.22, mr * 0.18), Color(hex: 0xE8D9A0))
            fill(circle(w * 0.72, h * 0.28, mr * 0.12), Color(hex: 0xE8D9A0))
            var back = Path()
            back.move(to: CGPoint(x: 0, y: h * 0.78))
            back.addLine(to: CGPoint(x: w * 0.3, y: h * 0.6))
            back.addLine(to: CGPoint(x: w * 0.55, y: h * 0.74))
            back.addLine(to: CGPoint(x: w * 0.8, y: h * 0.56))
            back.addLine(to: CGPoint(x: w, y: h * 0.7))
            back.addLine(to: CGPoint(x: w, y: h)); back.addLine(to: CGPoint(x: 0, y: h)); back.closeSubpath()
            fill(back, Color(hex: 0x2C3F80))
            var front = Path()
            front.move(to: CGPoint(x: 0, y: h * 0.88))
            front.addLine(to: CGPoint(x: w * 0.45, y: h * 0.7))
            front.addLine(to: CGPoint(x: w * 0.7, y: h * 0.84))
            front.addLine(to: CGPoint(x: w, y: h * 0.76))
            front.addLine(to: CGPoint(x: w, y: h)); front.addLine(to: CGPoint(x: 0, y: h)); front.closeSubpath()
            fill(front, Color(hex: 0x16214A))
            var snow = Path()
            snow.move(to: CGPoint(x: w * 0.8, y: h * 0.56))
            snow.addLine(to: CGPoint(x: w * 0.85, y: h * 0.585))
            snow.addLine(to: CGPoint(x: w * 0.75, y: h * 0.59))
            snow.closeSubpath()
            fill(snow, .white.opacity(0.85))

        case .lemons:
            fill(Path(rect), Color(hex: 0x2F5D8A))
            let step = w / 3.2
            var row = 0
            for y in stride(from: -step / 2, through: h + step, by: step * 0.8) {
                let offset = row % 2 == 0 ? 0 : step / 2
                for x in stride(from: -step / 2 + offset, through: w + step, by: step) {
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .degrees(rng.range(-40, 40)))
                    let lw = step * 0.42, lh = step * 0.3
                    c.fill(Path(ellipseIn: CGRect(x: -lw / 2, y: -lh / 2, width: lw, height: lh)), with: .color(Color(hex: 0xF7D33F)))
                    c.fill(Path(ellipseIn: CGRect(x: lw * 0.38, y: -lh * 0.12, width: lw * 0.18, height: lh * 0.24)), with: .color(Color(hex: 0xF7D33F)))
                    c.fill(Path(ellipseIn: CGRect(x: -lw * 0.25, y: -lh * 0.32, width: lw * 0.2, height: lh * 0.14)), with: .color(.white.opacity(0.35)))
                    var leaf = Path()
                    leaf.move(to: CGPoint(x: -lw * 0.5, y: 0))
                    leaf.addQuadCurve(to: CGPoint(x: -lw * 0.95, y: -lh * 0.55), control: CGPoint(x: -lw * 0.6, y: -lh * 0.7))
                    leaf.addQuadCurve(to: CGPoint(x: -lw * 0.5, y: 0), control: CGPoint(x: -lw * 0.95, y: 0))
                    c.fill(leaf, with: .color(Color(hex: 0x4BA35B)))
                }
                row += 1
            }

        case .monstera:
            fill(Path(rect), Color(hex: 0xF1ECDD))
            let leaves: [(Double, Double, Double, Double, UInt32)] = [
                (0.85, 0.3, 0.75, -30, 0x2F7A4D), (0.15, 0.85, 0.7, 150, 0x1F5C3A), (0.9, 0.95, 0.55, 200, 0x3F8F5C),
            ]
            for (lx, ly, scale, angle, color) in leaves {
                var c = ctx
                c.translateBy(x: w * lx, y: h * ly)
                c.rotate(by: .degrees(angle))
                let L = w * scale
                var leaf = Path()
                leaf.move(to: .zero)
                leaf.addCurve(to: CGPoint(x: L, y: 0), control1: CGPoint(x: L * 0.2, y: -L * 0.55), control2: CGPoint(x: L * 0.85, y: -L * 0.45))
                leaf.addCurve(to: .zero, control1: CGPoint(x: L * 0.85, y: L * 0.45), control2: CGPoint(x: L * 0.2, y: L * 0.55))
                c.fill(leaf, with: .color(Color(hex: color)))
                var vein = Path()
                vein.move(to: .zero); vein.addLine(to: CGPoint(x: L * 0.95, y: 0))
                c.stroke(vein, with: .color(Color(hex: 0xF1ECDD, opacity: 0.7)), lineWidth: L * 0.02)
                for i in 1...5 {
                    let t = Double(i) / 6
                    for side in [-1.0, 1.0] {
                        var slit = Path()
                        slit.move(to: CGPoint(x: L * t, y: side * L * 0.04))
                        slit.addLine(to: CGPoint(x: L * (t + 0.08), y: side * L * 0.38 * sin(.pi * t)))
                        c.stroke(slit, with: .color(Color(hex: 0xF1ECDD)), style: StrokeStyle(lineWidth: L * 0.035, lineCap: .round))
                    }
                }
            }

        case .waves:
            fill(Path(rect), Color(hex: 0x24396B))
            let r = w / 5
            var row = 0
            for y in stride(from: -r * 0.2, through: h + r, by: r * 0.5) {
                let offset = row % 2 == 0 ? 0 : r
                for x in stride(from: -r + offset, through: w + r, by: r * 2) {
                    for (i, k) in [1.0, 0.78, 0.56, 0.34].enumerated() {
                        let p = circle(x, y, r * k)
                        fill(p, i % 2 == 0 ? Color(hex: 0xEDE8DC) : Color(hex: 0x24396B))
                    }
                    fill(circle(x, y, r * 0.16), Color(hex: 0x4A6FB5))
                }
                row += 1
            }

        case .rainbow:
            fill(Path(rect), Color(hex: 0xE9C46A))
            let colors: [UInt32] = [0xE76F51, 0xF4E9D8, 0x2A9D8F, 0x264653]
            let cx = w * 0.45, cy = h * 0.95
            for (i, col) in colors.enumerated() {
                let r = w * (0.75 - Double(i) * 0.15)
                fill(circle(cx, cy, r), Color(hex: col))
            }
            fill(circle(cx, cy, w * 0.14), Color(hex: 0xE9C46A))
            fill(circle(w * 0.78, h * 0.22, w * 0.09), Color(hex: 0xF4E9D8))

        case .map:
            fill(Path(rect), Color(hex: 0xA9D6E5))
            for _ in 0..<10 {
                var wave = Path()
                let x = rng.next() * w, y = rng.next() * h
                wave.move(to: CGPoint(x: x, y: y))
                wave.addQuadCurve(to: CGPoint(x: x + w * 0.06, y: y), control: CGPoint(x: x + w * 0.03, y: y - w * 0.02))
                wave.addQuadCurve(to: CGPoint(x: x + w * 0.12, y: y), control: CGPoint(x: x + w * 0.09, y: y + w * 0.02))
                ctx.stroke(wave, with: .color(.white.opacity(0.7)), lineWidth: w * 0.008)
            }
            var island = Path()
            island.move(to: CGPoint(x: w * 0.15, y: h * 0.2))
            island.addCurve(to: CGPoint(x: w * 0.85, y: h * 0.25), control1: CGPoint(x: w * 0.35, y: h * 0.02), control2: CGPoint(x: w * 0.7, y: h * 0.08))
            island.addCurve(to: CGPoint(x: w * 0.7, y: h * 0.55), control1: CGPoint(x: w * 1.0, y: h * 0.4), control2: CGPoint(x: w * 0.85, y: h * 0.55))
            island.addCurve(to: CGPoint(x: w * 0.15, y: h * 0.2), control1: CGPoint(x: w * 0.4, y: h * 0.55), control2: CGPoint(x: w * 0.0, y: h * 0.4))
            fill(island, Color(hex: 0xF2E2B6))
            fill(circle(w * 0.38, h * 0.28, w * 0.09), Color(hex: 0x9CCB86))
            fill(circle(w * 0.48, h * 0.33, w * 0.07), Color(hex: 0x86BC72))
            var route = Path()
            route.move(to: CGPoint(x: w * 0.62, y: h * 0.38))
            route.addCurve(to: CGPoint(x: w * 0.3, y: h * 0.85), control1: CGPoint(x: w * 0.75, y: h * 0.6), control2: CGPoint(x: w * 0.2, y: h * 0.62))
            ctx.stroke(route, with: .color(Color(hex: 0xD64545)), style: StrokeStyle(lineWidth: w * 0.012, dash: [w * 0.03, w * 0.025]))
            fill(circle(w * 0.62, h * 0.36, w * 0.035), Color(hex: 0xD64545))
            fill(circle(w * 0.62, h * 0.36, w * 0.014), .white)
            let cc = CGPoint(x: w * 0.75, y: h * 0.82)
            fill(circle(cc.x, cc.y, w * 0.1), .white.opacity(0.9))
            var needle = Path()
            needle.move(to: CGPoint(x: cc.x, y: cc.y - w * 0.08))
            needle.addLine(to: CGPoint(x: cc.x + w * 0.025, y: cc.y))
            needle.addLine(to: CGPoint(x: cc.x, y: cc.y + w * 0.08))
            needle.addLine(to: CGPoint(x: cc.x - w * 0.025, y: cc.y))
            needle.closeSubpath()
            fill(needle, Color(hex: 0x24396B))

        case .forest:
            ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: [Color(hex: 0xCFE3D4), Color(hex: 0x7DAA8C)]),
                                                     startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            fill(circle(w * 0.25, h * 0.2, w * 0.1), Color(hex: 0xFFF6E0))
            for layer in 0..<3 {
                let colors: [UInt32] = [0x5E8F72, 0x3E7158, 0x24503D]
                let baseY = h * (0.55 + Double(layer) * 0.15)
                var x = -w * 0.1
                while x < w * 1.1 {
                    let tw = w * rng.range(0.14, 0.22), th = tw * rng.range(1.6, 2.4)
                    var tree = Path()
                    tree.move(to: CGPoint(x: x, y: baseY))
                    tree.addLine(to: CGPoint(x: x + tw / 2, y: baseY - th))
                    tree.addLine(to: CGPoint(x: x + tw, y: baseY))
                    tree.closeSubpath()
                    fill(tree, Color(hex: colors[layer]))
                    x += tw * 0.7
                }
                fill(Path(CGRect(x: 0, y: baseY - 1, width: w, height: h - baseY + 1)), Color(hex: colors[layer]))
            }

        case .sunset:
            ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: [Color(hex: 0xFFC48C), Color(hex: 0xF08A5D), Color(hex: 0xB83B5E)]),
                                                     startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.65)))
            fill(circle(w * 0.5, h * 0.62, w * 0.26), Color(hex: 0xFFE8A3))
            fill(Path(CGRect(x: 0, y: h * 0.62, width: w, height: h * 0.38)), Color(hex: 0x6A2C70))
            for i in 0..<6 {
                let y = h * (0.66 + Double(i) * 0.05)
                let lw = w * (0.4 - Double(i) * 0.05)
                fill(Path(roundedRect: CGRect(x: w * 0.5 - lw / 2, y: y, width: lw, height: h * 0.012), cornerRadius: 2),
                     Color(hex: 0xFFE8A3, opacity: 0.6))
            }

        case .watermelon:
            fill(Path(rect), Color(hex: 0xBFE6CF))
            let step = w / 2.6
            var row = 0
            for y in stride(from: step * 0.2, through: h + step, by: step * 0.85) {
                let offset = row % 2 == 0 ? 0.0 : step / 2
                for x in stride(from: offset - step / 2, through: w + step, by: step) {
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .degrees(rng.range(-25, 25) + (row % 2 == 0 ? 0 : 180)))
                    let s = step * 0.42
                    var rind = Path()
                    rind.move(to: CGPoint(x: -s, y: 0))
                    rind.addArc(center: .zero, radius: s, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
                    rind.closeSubpath()
                    c.fill(rind, with: .color(Color(hex: 0x3E9B57)))
                    var flesh = Path()
                    flesh.move(to: CGPoint(x: -s * 0.85, y: 0))
                    flesh.addArc(center: .zero, radius: s * 0.85, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
                    flesh.closeSubpath()
                    c.fill(flesh, with: .color(Color(hex: 0xF25F6B)))
                    for k in 0..<4 {
                        let a = Double.pi * (0.2 + Double(k) * 0.2)
                        c.fill(Path(ellipseIn: CGRect(x: cos(a) * s * 0.5 - 2, y: sin(a) * s * 0.5 - 3, width: s * 0.07, height: s * 0.11)),
                               with: .color(Color(hex: 0x2B2D33)))
                    }
                }
                row += 1
            }

        case .terrazzo:
            fill(Path(rect), Color(hex: 0xF3EDE4))
            let palette: [UInt32] = [0xE76F51, 0x2A9D8F, 0xE9C46A, 0x264653, 0xF4A261, 0xB5838D]
            for _ in 0..<55 {
                var chip = Path()
                let cx = rng.next() * w, cy = rng.next() * h, r = w * rng.range(0.015, 0.05)
                let n = 5
                for i in 0..<n {
                    let a = Double(i) / Double(n) * 2 * .pi + rng.range(-0.4, 0.4)
                    let rr = r * rng.range(0.6, 1.2)
                    let p = CGPoint(x: cx + cos(a) * rr, y: cy + sin(a) * rr)
                    i == 0 ? chip.move(to: p) : chip.addLine(to: p)
                }
                chip.closeSubpath()
                fill(chip, Color(hex: palette[Int(rng.next() * Double(palette.count)) % palette.count]))
            }

        case .blossom:
            fill(Path(rect), Color(hex: 0xE8B4B8))
            for _ in 0..<9 {
                let cx = rng.next() * w, cy = rng.next() * h, r = w * rng.range(0.06, 0.11)
                for k in 0..<5 {
                    let a = Double(k) / 5 * 2 * .pi
                    fill(circle(cx + cos(a) * r * 0.8, cy + sin(a) * r * 0.8, r * 0.62), Color(hex: 0xFFF5F2, opacity: 0.95))
                }
                fill(circle(cx, cy, r * 0.32), Color(hex: 0xF2B544))
            }
            for _ in 0..<14 {
                var c = ctx
                c.translateBy(x: rng.next() * w, y: rng.next() * h)
                c.rotate(by: .degrees(rng.range(0, 360)))
                c.fill(Path(ellipseIn: CGRect(x: 0, y: 0, width: w * 0.08, height: w * 0.035)), with: .color(Color(hex: 0x7FA37E)))
            }

        case .kraft:
            fill(Path(rect), Color(hex: 0xC9A27A))
            for _ in 0..<500 {
                fill(circle(rng.next() * w, rng.next() * h, w * 0.003), Color(hex: 0x8C6A48, opacity: 0.35))
            }
            let g = w / 10
            for x in stride(from: g, to: w, by: g) {
                for y in stride(from: g, to: h, by: g) {
                    fill(circle(x, y, w * 0.006), Color(hex: 0x6E5034, opacity: 0.45))
                }
            }

        case .sage, .clay, .ink:
            let base: UInt32 = style == .sage ? 0x9CB59A : style == .clay ? 0xC2725A : 0x2B2D33
            fill(Path(rect), Color(hex: base))
            // Linen weave
            for y in stride(from: 0.0, to: h, by: 2.5) {
                fill(Path(CGRect(x: 0, y: y, width: w, height: 0.6)), .black.opacity(0.05))
            }
            for x in stride(from: 0.0, to: w, by: 2.5) {
                fill(Path(CGRect(x: x, y: 0, width: 0.6, height: h)), .white.opacity(0.05))
            }
            // A debossed band
            fill(Path(CGRect(x: w * 0.78, y: 0, width: w * 0.05, height: h)), .black.opacity(0.18))

        case .blush, .photo:
            break
        }
    }
}

private extension String {
    /// `hashValue` is randomised per launch; this one is stable.
    var hashValueStable: Int {
        var h: UInt64 = 5381
        for b in utf8 { h = (h &* 33) &+ UInt64(b) }
        return Int(truncatingIfNeeded: h)
    }
}

// MARK: - Notebook cover with spine, page edges and shadow

struct NotebookCover: View {
    var style: CoverStyle
    var photo: Data? = nil
    var title: String? = nil
    var showLabel: Bool = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let shape = UnevenRoundedRectangle(topLeadingRadius: w * 0.025, bottomLeadingRadius: w * 0.025,
                                               bottomTrailingRadius: w * 0.07, topTrailingRadius: w * 0.07,
                                               style: .continuous)
            ZStack {
                // Pages peeking out
                shape.fill(Color(hex: 0xFBF8F2))
                    .overlay(shape.strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
                    .offset(x: w * 0.025, y: w * 0.012)
                    .padding(.vertical, w * 0.02)

                CoverArt(style: style, photo: photo)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipShape(shape)
                    .overlay {
                        // Spine shading + highlight
                        HStack(spacing: 0) {
                            LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.05), .white.opacity(0.18), .clear],
                                           startPoint: .leading, endPoint: .trailing)
                                .frame(width: w * 0.11)
                            Spacer()
                        }
                        .clipShape(shape)
                    }
                    .overlay {
                        // Soft sheen
                        LinearGradient(colors: [.white.opacity(0.14), .clear, .black.opacity(0.08)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                            .clipShape(shape)
                    }
                    .overlay(shape.strokeBorder(.black.opacity(0.08), lineWidth: 0.5))
                    .overlay(alignment: .center) {
                        if showLabel, let title {
                            Text(title)
                                .font(.system(size: max(10, w * 0.085), weight: .semibold, design: .serif))
                                .foregroundStyle(Color(hex: 0x2A2622))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, w * 0.06)
                                .padding(.vertical, w * 0.035)
                                .frame(maxWidth: w * 0.7)
                                .background(Color(hex: 0xFBF8F2), in: RoundedRectangle(cornerRadius: w * 0.02))
                                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                                .offset(x: w * 0.04)
                        }
                    }
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.10), radius: w * 0.02, x: 0, y: w * 0.01)
            .shadow(color: .black.opacity(0.14), radius: w * 0.07, x: w * 0.02, y: w * 0.06)
        }
        .aspectRatio(0.72, contentMode: .fit)
    }
}

/// A notebook seen side-on, for the archive shelf.
struct NotebookSpine: View {
    var style: CoverStyle
    var photo: Data?
    var title: String
    var height: CGFloat = 150

    var body: some View {
        let width = height * 0.24
        ZStack {
            CoverArt(style: style, photo: photo)
                .frame(width: height * 0.72, height: height)
                .frame(width: width, height: height)
                .clipped()
            LinearGradient(colors: [.black.opacity(0.25), .white.opacity(0.15), .clear, .black.opacity(0.25)],
                           startPoint: .leading, endPoint: .trailing)
            VStack {
                Rectangle().fill(Color(hex: 0xE9D9A6)).frame(height: 2).padding(.top, 8)
                Rectangle().fill(Color(hex: 0xE9D9A6)).frame(height: 1)
                Spacer()
            }
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .serif))
                .foregroundStyle(Color(hex: 0x2A2622))
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(hex: 0xFBF8F2), in: RoundedRectangle(cornerRadius: 2))
                .fixedSize()
                .rotationEffect(.degrees(90))
                .frame(width: width, height: height * 0.8)
        }
        .frame(width: width, height: height)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 1, bottomTrailingRadius: 1, topTrailingRadius: 3))
        .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 20)], spacing: 24) {
            ForEach(CoverStyle.illustrated) { s in
                NotebookCover(style: s)
            }
        }
        .padding()
    }
}
