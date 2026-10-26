import SwiftUI

enum Season: String, CaseIterable {
    case spring, summer, autumn, winter

    static func current(_ date: Date = Date()) -> Season {
        switch Calendar.current.component(.month, from: date) {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }

    var name: String { rawValue.capitalized }

    var theme: Theme {
        switch self {
        case .autumn:
            return Theme(name: "Autumn", ground: Color(hex: 0x1A120E), card: Color(hex: 0x2A1C16, opacity: 0.88),
                         chip: Color(hex: 0x3A2820), lit: Color(hex: 0x4A3322), accent: Color(hex: 0xF2A65A),
                         decor: [Color(hex: 0xC8642E), Color(hex: 0xE09A3E), Color(hex: 0xA6402A), Color(hex: 0xD9B04A)],
                         symbol: "leaf.fill")
        case .winter:
            return Theme(name: "Winter", ground: Color(hex: 0x0C1220), card: Color(hex: 0x162032, opacity: 0.88),
                         chip: Color(hex: 0x24324C), lit: Color(hex: 0x2C4366), accent: Color(hex: 0x9CCBFF),
                         decor: [Color(hex: 0xCFE3FF), Color(hex: 0xA9C8F0), Color(hex: 0xE8F1FF), Color(hex: 0x88AEDD)],
                         symbol: "snowflake")
        case .spring:
            return Theme(name: "Spring", ground: Color(hex: 0x0F1712), card: Color(hex: 0x18261E, opacity: 0.88),
                         chip: Color(hex: 0x28402F), lit: Color(hex: 0x3A4A34), accent: Color(hex: 0xF4A8C4),
                         decor: [Color(hex: 0xF4A8C4), Color(hex: 0xF7C6D6), Color(hex: 0xE58AAE), Color(hex: 0xFBE0E8)],
                         symbol: "camera.macro")
        case .summer:
            return Theme(name: "Summer", ground: Color(hex: 0x0B1619), card: Color(hex: 0x122428, opacity: 0.88),
                         chip: Color(hex: 0x1F3B40), lit: Color(hex: 0x3A4A34), accent: Color(hex: 0xFFD166),
                         decor: [Color(hex: 0xFFD166), Color(hex: 0xFFB347), Color(hex: 0xFFE29A), Color(hex: 0x7FD8C9)],
                         symbol: "sun.max.fill")
        }
    }
}

struct Theme {
    let name: String
    let ground: Color
    let card: Color
    let chip: Color
    let lit: Color
    let accent: Color
    let decor: [Color]
    let symbol: String

    /// Rustic, woodland-storybook font (Papyrus ships with iOS).
    static func woodland(_ size: CGFloat) -> Font { .custom("Papyrus", size: size) }

    static let fg = Color(hex: 0xF5F1EA)
    static let muted = Color(hex: 0xC9C1B6)
    static let faint = Color(hex: 0x8E867C)
    static let fieldBorder = Color(hex: 0x4A4038)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

// MARK: - Shared building blocks

struct SectionLabel: View {
    let text: String
    var size: CGFloat = 26
    var woodland = false

    init(_ text: String, size: CGFloat = 26, woodland: Bool = false) {
        self.text = text
        self.size = size
        self.woodland = woodland
    }

    var body: some View {
        Text(text.uppercased())
            .font(woodland ? Theme.woodland(size) : .system(size: size, weight: .semibold))
            .tracking(2)
            .foregroundStyle(Theme.muted)
    }
}

extension View {
    func card(_ theme: Theme, padding: CGFloat = 32, radius: CGFloat = 28) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    func panelField(_ theme: Theme) -> some View {
        self
            .font(.system(size: 18))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(theme.ground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.fieldBorder, lineWidth: 2))
    }
}

/// Seasonal shapes scattered in the margins (leaves, snowflakes, blossoms, sun).
struct DecorLayer: View {
    typealias Spot = (x: CGFloat, y: CGFloat, size: CGFloat, angle: Double)
    let theme: Theme
    let spots: [Spot]

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack(alignment: .topLeading) {
                    ForEach(spots.indices, id: \.self) { i in
                        let s = spots[i]
                        // Each shape drifts from above the top edge to below the bottom edge, then loops.
                        let period = 18.0 + Double(i % 5) * 4
                        let phase = Double(i) * 0.37 + Double(s.y) / 2000
                        let progress = (t / period + phase).truncatingRemainder(dividingBy: 1)
                        // Pendulum-style flutter: the leaf swings side to side, tilts into each swing,
                        // and dips a little at the turn of each swing like a real falling leaf.
                        let swing = sin(t * 1.1 + Double(i) * 1.3)
                        let swingRate = cos(t * 1.1 + Double(i) * 1.3)
                        let fall = -s.size + CGFloat(progress) * (geo.size.height + s.size * 2)
                            + CGFloat(abs(swingRate)) * 10
                        let sway = CGFloat(swing) * 36
                        let spin = s.angle + swing * 40 + progress * 60
                        // Fade in/out near the ends so loops don't pop.
                        let edgeFade = min(1, progress * 12, (1 - progress) * 12)
                        Image(systemName: theme.symbol)
                            .font(.system(size: s.size))
                            .foregroundStyle(theme.decor[i % theme.decor.count])
                            .rotationEffect(.degrees(spin))
                            .opacity((0.35 + Double(i % 3) * 0.12) * edgeFade)
                            .position(x: s.x + sway, y: fall)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Centers on the 1080 × 1920 TV layout, kept to the edges so nothing covers text.
    static let tvSpots: [Spot] = [
        (588, 32, 56, 70), (726, 18, 72, 20),
        (18, 282, 84, -45), (10, 640, 80, 40), (19, 1055, 110, -20), (18, 1418, 76, 25), (16, 1720, 60, -30),
        (1055, 415, 70, -30), (1057, 825, 90, 12), (1060, 1150, 60, 55), (1066, 1490, 100, -15), (1060, 1756, 72, -8),
        (445, 1897, 50, 35), (765, 1905, 90, 20)
    ]

    static func panelSpots(_ size: CGSize) -> [Spot] {
        [(size.width - 20, 20, 56, 20), (12, size.height * 0.8, 50, -30),
         (size.width * 0.5, size.height - 6, 40, 40), (size.width - 14, size.height * 0.62, 44, 60)]
    }
}

// MARK: - Halloween ghost

/// A cute little ghost body: round head, wavy hem.
struct GhostShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, r = w / 2
        let hem = h * 0.85
        var p = Path()
        p.move(to: CGPoint(x: 0, y: hem))
        p.addLine(to: CGPoint(x: 0, y: r))
        p.addArc(center: CGPoint(x: r, y: r), radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: w, y: hem))
        // Three scallops along the bottom, right to left.
        let step = w / 3
        for i in 0..<3 {
            p.addQuadCurve(to: CGPoint(x: w - step * CGFloat(i + 1), y: hem),
                           control: CGPoint(x: w - step * (CGFloat(i) + 0.5), y: h * 1.15))
        }
        p.closeSubpath()
        return p
    }
}

/// A small translucent ghost that floats across the screen every so often during Halloween season.
/// Sits above the content but is faint enough to read through, and never takes touches.
struct GhostOverlay: View {
    private static let cycle = 50.0      // seconds between visits
    private static let visit = 16.0      // seconds it takes to cross the screen

    /// October through Halloween night.
    static func isHalloween(_ date: Date = Date()) -> Bool {
        Calendar.current.component(.month, from: date) == 10
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let local = t.truncatingRemainder(dividingBy: Self.cycle)
                if Self.isHalloween(timeline.date) && local < Self.visit {
                    let visitIndex = Int(t / Self.cycle)
                    let progress = local / Self.visit
                    let size = min(max(geo.size.width * 0.08, 60), 110)
                    let leftToRight = visitIndex.isMultiple(of: 2)
                    // Starts and ends just off-screen.
                    let travel = geo.size.width + size * 2
                    let x = (leftToRight ? progress : 1 - progress) * travel - size
                    // A lazy, bobbing line that wanders a little each visit.
                    let baseY = geo.size.height * (0.25 + Double(visitIndex % 4) * 0.15)
                    let y = baseY + sin(progress * 9) * size * 0.45
                    let fade = min(1, progress * 8, (1 - progress) * 8)
                    ghost(size: size, facingRight: leftToRight, blink: t)
                        .rotationEffect(.degrees(sin(progress * 9 + 1) * 8))
                        .opacity(0.32 * fade)
                        .position(x: x, y: y)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func ghost(size: CGFloat, facingRight: Bool, blink t: Double) -> some View {
        let h = size * 1.2
        // Quick blink every few seconds.
        let eyeHeight = t.truncatingRemainder(dividingBy: 4) < 0.15 ? size * 0.02 : size * 0.15
        let look: CGFloat = facingRight ? size * 0.03 : -size * 0.03
        return ZStack {
            GhostShape()
                .fill(Color(hex: 0xD9D2FF))
                .frame(width: size, height: h)
                .shadow(color: Color(hex: 0xB8A8FF), radius: size * 0.2)
            HStack(spacing: size * 0.2) {
                Ellipse().fill(Color(hex: 0x2A2340)).frame(width: size * 0.13, height: eyeHeight)
                Ellipse().fill(Color(hex: 0x2A2340)).frame(width: size * 0.13, height: eyeHeight)
            }
            .offset(x: look, y: -h * 0.12)
            HStack(spacing: size * 0.42) {
                Circle().fill(Color(hex: 0xF4A8C4).opacity(0.8)).frame(width: size * 0.12)
                Circle().fill(Color(hex: 0xF4A8C4).opacity(0.8)).frame(width: size * 0.12)
            }
            .offset(x: look, y: -h * 0.02)
            // A tiny "o" mouth.
            Circle().fill(Color(hex: 0x2A2340)).frame(width: size * 0.1)
                .offset(x: look, y: h * 0.08)
        }
        .frame(width: size, height: h)
    }
}
