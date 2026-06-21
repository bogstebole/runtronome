import SwiftUI

/// Reusable styled button label. Use inside `Button` or `Menu` — the caller owns the interaction.
struct RuntronomeButton: View {
    enum Style {
        case circular(systemImage: String)
        case pill(text: String)
    }

    var style: Style

    var body: some View {
        switch style {
        case .circular(let image):
            ZStack {
                Circle()
                    .fill(Color(white: 0.32))
                    .frame(width: 52, height: 52)
                Image(systemName: image)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
        case .pill(let text):
            Text(text)
                .font(.momoTrust(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.28))
                )
        }
    }
}
