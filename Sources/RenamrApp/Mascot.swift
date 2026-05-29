import SwiftUI

/// Sprig — Renamr's mascot. A cheerful little sprout who tidies your files.
/// Drawn entirely in vectors so it stays crisp at any size and ships in the app.
struct Mascot: View {
    enum Mood { case idle, happy, thinking }

    var mood: Mood = .idle
    var size: CGFloat = 96
    var animated: Bool = true

    @State private var bob = false
    @State private var blink = false

    private var S: CGFloat { size }

    var body: some View {
        ZStack {
            sprout
            body_
            face
        }
        .frame(width: S, height: S)
        .offset(y: animated && bob ? -S * 0.03 : S * 0.01)
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) { bob = true }
        }
    }

    // Two leaves + a tiny blossom peeking above the body.
    private var sprout: some View {
        ZStack {
            LeafShape()
                .fill(Brand.leafGradient)
                .frame(width: S * 0.30, height: S * 0.40)
                .rotationEffect(.degrees(-34))
                .offset(x: -S * 0.12, y: -S * 0.26)
            LeafShape()
                .fill(Brand.leafGradient)
                .frame(width: S * 0.30, height: S * 0.40)
                .rotationEffect(.degrees(34))
                .offset(x: S * 0.12, y: -S * 0.26)
            Blossom()
                .fill(Brand.blossom)
                .frame(width: S * 0.16, height: S * 0.16)
                .offset(x: S * 0.20, y: -S * 0.36)
            Circle().fill(.white.opacity(0.9))
                .frame(width: S * 0.05, height: S * 0.05)
                .offset(x: S * 0.20, y: -S * 0.36)
        }
    }

    private var body_: some View {
        Ellipse()
            .fill(Brand.gradient)
            .frame(width: S * 0.62, height: S * 0.56)
            .overlay(
                Ellipse().fill(.white.opacity(0.18))
                    .frame(width: S * 0.30, height: S * 0.22)
                    .offset(x: -S * 0.10, y: -S * 0.10)
            )
            .offset(y: S * 0.10)
    }

    private var face: some View {
        ZStack {
            // cheeks
            HStack(spacing: S * 0.26) {
                Circle().fill(Brand.blossom.opacity(0.55)).frame(width: S * 0.08, height: S * 0.08)
                Circle().fill(Brand.blossom.opacity(0.55)).frame(width: S * 0.08, height: S * 0.08)
            }
            .offset(y: S * 0.16)

            // eyes
            HStack(spacing: S * 0.16) {
                eye
                eye
            }
            .offset(y: mood == .thinking ? S * 0.04 : S * 0.07)

            // mouth
            mouth.offset(y: S * 0.18)
        }
    }

    @ViewBuilder private var eye: some View {
        switch mood {
        case .happy:
            ArcEye().stroke(Color.black.opacity(0.82), style: .init(lineWidth: S * 0.022, lineCap: .round))
                .frame(width: S * 0.08, height: S * 0.05)
        default:
            ZStack {
                Circle().fill(Color.black.opacity(0.82)).frame(width: S * 0.075, height: S * 0.075)
                Circle().fill(.white).frame(width: S * 0.025, height: S * 0.025)
                    .offset(x: S * 0.015, y: -S * 0.015)
            }
            .scaleEffect(y: blink ? 0.1 : 1.0, anchor: .center)
            .onAppear {
                guard animated else { return }
                withAnimation(.easeInOut(duration: 0.12).delay(2.8).repeatForever(autoreverses: true)) { blink = true }
            }
        }
    }

    @ViewBuilder private var mouth: some View {
        switch mood {
        case .happy:
            Smile(openness: 0.9).fill(Color.black.opacity(0.72))
                .frame(width: S * 0.14, height: S * 0.09)
        case .thinking:
            Circle().fill(Color.black.opacity(0.6)).frame(width: S * 0.035, height: S * 0.035)
        case .idle:
            Smile(openness: 0.0).stroke(Color.black.opacity(0.72), style: .init(lineWidth: S * 0.022, lineCap: .round))
                .frame(width: S * 0.12, height: S * 0.06)
        }
    }
}

// MARK: - Shapes

struct LeafShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: CGPoint(x: r.maxX, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY), control: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        return p
    }
}

/// A curve that's a gentle smile when openness=0 and an open grin when openness=1.
struct Smile: Shape {
    var openness: CGFloat = 0
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY))
        if openness > 0 {
            p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY),
                           control: CGPoint(x: r.midX, y: r.maxY * (1 - openness)))
            p.closeSubpath()
        }
        return p
    }
}

struct ArcEye: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.midX, y: r.minY))
        return p
    }
}

struct Blossom: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let petal = min(r.width, r.height) * 0.30
        for i in 0..<5 {
            let a = (CGFloat(i) / 5) * 2 * .pi - .pi / 2
            let pc = CGPoint(x: c.x + cos(a) * petal, y: c.y + sin(a) * petal)
            p.addEllipse(in: CGRect(x: pc.x - petal, y: pc.y - petal, width: petal * 2, height: petal * 2))
        }
        return p
    }
}
