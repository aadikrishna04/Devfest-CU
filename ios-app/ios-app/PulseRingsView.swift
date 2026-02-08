import SwiftUI

/// Animated concentric rings with rotating arcs, dots, and pulse — futuristic HUD style
struct PulseRingsView: View {
    @State private var rotation1: Double = 0
    @State private var rotation2: Double = 0
    @State private var rotation3: Double = 0
    @State private var pulse: CGFloat = 1.0
    @State private var heartBeat: CGFloat = 1.0
    @State private var glowPulse: CGFloat = 1.0

    let color: Color

    init(color: Color = MedkitTheme.accent) {
        self.color = color
    }

    var body: some View {
        ZStack {
            // Large diffused background glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(0.16),
                            color.opacity(0.08),
                            color.opacity(0.03),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .scaleEffect(glowPulse)
                .blur(radius: 12)

            // Outer pulse ring
            Circle()
                .stroke(color.opacity(0.1), lineWidth: 1.5)
                .frame(width: 320, height: 320)
                .scaleEffect(pulse)

            // Ring 1 — large, slow rotation
            ring(radius: 150, dotCount: 14, arcSpan: 0.3, lineWidth: 1.8, opacity: 0.2)
                .rotationEffect(.degrees(rotation1))

            // Ring 2 — medium, medium speed
            ring(radius: 115, dotCount: 10, arcSpan: 0.45, lineWidth: 2.0, opacity: 0.28)
                .rotationEffect(.degrees(rotation2))

            // Ring 3 — small, fast rotation
            ring(radius: 82, dotCount: 8, arcSpan: 0.25, lineWidth: 1.5, opacity: 0.22)
                .rotationEffect(.degrees(rotation3))

            // Inner dashed circle
            Circle()
                .stroke(color.opacity(0.15), style: StrokeStyle(lineWidth: 1.0, dash: [4, 6]))
                .frame(width: 105, height: 105)
                .rotationEffect(.degrees(-rotation2))

            // Connecting spokes from heart to rings
            ForEach(0..<6, id: \.self) { i in
                let angle = (Double(i) / 6.0) * 2 * .pi
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.25), color.opacity(0.03)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 40, height: 1.2)
                    .offset(x: 42, y: 0)
                    .rotationEffect(.radians(angle))
            }

            // Heart glow — layered for depth
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.28), color.opacity(0.10), color.opacity(0.03), Color.clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(heartBeat)
                .blur(radius: 4)

            // Beating heart
            Image(systemName: "heart.fill")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(heartBeat)
                .shadow(color: color.opacity(0.5), radius: 16, y: 2)
                .shadow(color: color.opacity(0.25), radius: 30, y: 4)
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotation1 = 360
            }
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                rotation2 = -360
            }
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                rotation3 = 360
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                pulse = 1.08
            }
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                glowPulse = 1.06
            }
            startHeartbeat()
        }
    }

    // Double-pump heartbeat: thump-thump ... pause ... thump-thump
    private func startHeartbeat() {
        func beat() {
            // First pump
            withAnimation(.easeOut(duration: 0.12)) { heartBeat = 1.18 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeIn(duration: 0.1)) { heartBeat = 1.0 }
            }
            // Second pump
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                withAnimation(.easeOut(duration: 0.1)) { heartBeat = 1.12 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                withAnimation(.easeIn(duration: 0.14)) { heartBeat = 1.0 }
            }
            // Pause then repeat
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                beat()
            }
        }
        beat()
    }

    private func ring(radius: CGFloat, dotCount: Int, arcSpan: Double, lineWidth: CGFloat, opacity: Double) -> some View {
        ZStack {
            // Segmented arc
            Circle()
                .trim(from: 0, to: arcSpan)
                .stroke(color.opacity(opacity), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: radius * 2, height: radius * 2)

            // Second arc segment opposite side
            Circle()
                .trim(from: 0.5, to: 0.5 + arcSpan * 0.6)
                .stroke(color.opacity(opacity * 0.7), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: radius * 2, height: radius * 2)

            // Third small arc
            Circle()
                .trim(from: 0.75, to: 0.75 + arcSpan * 0.3)
                .stroke(color.opacity(opacity * 0.5), style: StrokeStyle(lineWidth: lineWidth * 0.7, lineCap: .round))
                .frame(width: radius * 2, height: radius * 2)

            // Dots along the circle
            ForEach(0..<dotCount, id: \.self) { i in
                let angle = (Double(i) / Double(dotCount)) * 2 * .pi
                Circle()
                    .fill(color.opacity(opacity * 2.0))
                    .frame(width: 3.5, height: 3.5)
                    .offset(
                        x: cos(angle) * radius,
                        y: sin(angle) * radius
                    )
            }
        }
    }
}
