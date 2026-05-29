import SwiftUI

/// Sprig — Renamr's mascot. A simple, friendly sprout: one round green body, a
/// single leaf, two dot eyes, a soft smile. Drawn in vectors so it stays crisp.
struct Mascot: View {
    enum Mood { case idle, happy, thinking }

    var mood: Mood = .idle
    var size: CGFloat = 96
    var animated: Bool = true

    @State private var bob = false
    private var S: CGFloat { size }

    var body: some View {
        ZStack {
            Circle()
                .fill(Brand.gradient)
                .frame(width: S * 0.84, height: S * 0.84)
                .overlay(
                    Ellipse().fill(.white.opacity(0.16))
                        .frame(width: S * 0.38, height: S * 0.22)
                        .offset(x: -S * 0.13, y: -S * 0.16)
                )
            face
        }
        .frame(width: S, height: S)
        .offset(y: animated && bob ? -S * 0.02 : 0)
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { bob = true }
        }
    }

    private var eyeColor: Color { Color(red: 0.10, green: 0.20, blue: 0.15) }

    private var face: some View {
        VStack(spacing: S * 0.05) {
            HStack(spacing: S * 0.17) {
                Circle().fill(eyeColor).frame(width: S * 0.07, height: S * 0.07)
                Circle().fill(eyeColor).frame(width: S * 0.07, height: S * 0.07)
            }
            Smile(openness: 0)
                .stroke(eyeColor, style: .init(lineWidth: S * 0.024, lineCap: .round))
                .frame(width: mood == .happy ? S * 0.18 : S * 0.13,
                       height: mood == .thinking ? S * 0.02 : S * 0.07)
        }
        .offset(y: S * 0.02)
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

/// A gentle smile arc.
struct Smile: Shape {
    var openness: CGFloat = 0
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY))
        return p
    }
}
