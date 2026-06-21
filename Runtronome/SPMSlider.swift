import SwiftUI

struct SPMSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    private let tickCount = 10

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let fillW = w * max(progress, 0)

            ZStack(alignment: .leading) {
                // Background — #FFFFFF30
                Color.white.opacity(0.188)

                // Value fill — #FFFFFFB3, clipped by outer clipShape
                Color.white.opacity(0.702)
                    .frame(width: max(fillW, 0))
                    .frame(maxHeight: .infinity)

                // Fixed tick marks — space-between, paddingInline 16pt
                // Color #767676 + hard-light blend mode
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
                        let pct = min(max(Double(drag.location.x / w), 0), 1)
                        let newValue = (range.lowerBound + pct * (range.upperBound - range.lowerBound)).rounded()
                        value = newValue
                    }
            )
        }
        .frame(height: 56)
        // Fires on every 1-SPM step — ratchet/gear feel
        .sensoryFeedback(.selection, trigger: value)
    }
}
