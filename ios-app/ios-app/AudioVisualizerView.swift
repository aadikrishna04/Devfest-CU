import SwiftUI

struct AudioVisualizerView: View {
    let isActive: Bool

    private let barCount = 5
    private let barWidth: CGFloat = 32
    private let spacing: CGFloat = 14

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { index in
                AudioBar(
                    isActive: isActive,
                    maxHeight: maxHeights[index],
                    minHeight: 30,
                    duration: durations[index],
                    delay: Double(index) * 0.1,
                    width: barWidth
                )
            }
        }
    }

    private let maxHeights: [CGFloat] = [85, 135, 175, 125, 80]
    private let durations: [Double] = [0.55, 0.7, 0.6, 0.75, 0.5]
}

private struct AudioBar: View {
    let isActive: Bool
    let maxHeight: CGFloat
    let minHeight: CGFloat
    let duration: Double
    let delay: Double
    let width: CGFloat

    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: width / 2)
            .fill(
                LinearGradient(
                    colors: [MedkitTheme.accent, MedkitTheme.accentSoft],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: width, height: isAnimating ? maxHeight : minHeight)
            .animation(
                isActive
                    ? .easeInOut(duration: duration).repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.4),
                value: isAnimating
            )
            .onAppear {
                guard isActive else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    isAnimating = true
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        isAnimating = true
                    }
                } else {
                    isAnimating = false
                }
            }
    }
}
