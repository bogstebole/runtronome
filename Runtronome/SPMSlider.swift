import SwiftUI

struct SPMSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @Binding var isActive: Bool

    private let tickCount = 10

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let fillW = w * max(progress, 0)

            ZStack(alignment: .leading) {
                Color.white.opacity(0.188)

                Color.white.opacity(0.702)
                    .frame(width: max(fillW, 0))
                    .frame(maxHeight: .infinity)

                HStack {
                    ForEach(0..<tickCount, id: \.self) { i in
                        Rectangle()
                            .fill(Color(white: 0.463))
                            .blendMode(.hardLight)
                            .frame(width: 2, height: 16)
                        if i < tickCount - 1 {
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if !isActive {
                            // Animate only the activation — not the fill/tick updates
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                isActive = true
                            }
                        }
                        let pct = min(max(Double(drag.location.x / w), 0), 1)
                        value = (range.lowerBound + pct * (range.upperBound - range.lowerBound)).rounded()
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                            isActive = false
                        }
                    }
            )
        }
        .frame(height: 56)
        .scaleEffect(isActive ? 1.15 : 1.0)
        .shadow(
            color: .black.opacity(isActive ? 0.5 : 0),
            radius: isActive ? 20 : 0,
            x: 0,
            y: isActive ? 8 : 0
        )
        .zIndex(isActive ? 1 : 0)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0), trigger: isActive) { _, new in new }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: isActive) { _, new in !new }
        .sensoryFeedback(.selection, trigger: value)
    }
}
