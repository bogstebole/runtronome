import SwiftUI

/// Tap-to-type numeric field: shows the value (or an em dash when unset) over
/// a thin input underline; tapping focuses a number-pad TextField in place.
struct NumberField<Field: Hashable>: View {
    @Binding var value: Int?
    var range: ClosedRange<Int>
    /// Small unit label under the number, e.g. "MIN".
    var caption: String? = nil
    var width: CGFloat = 52
    var focused: FocusState<Field?>.Binding
    var field: Field

    @State private var text = ""

    private var isEditing: Bool { focused.wrappedValue == field }

    var body: some View {
        VStack(spacing: 2) {
            Group {
                if isEditing {
                    TextField("", text: $text)
                        .font(.anton(size: 22))
                        .foregroundColor(Theme.textPrimary)
                        .tint(Theme.textPrimary)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .focused(focused, equals: field)
                } else {
                    Text(value.map(String.init) ?? "—")
                        .font(.anton(size: 22))
                        .foregroundColor(value == nil ? Theme.textTertiary : Theme.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.15), value: value)
                }
            }
            .frame(width: width, height: 30)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isEditing ? Theme.textPrimary : Theme.stroke)
                    .frame(height: 1)
                    .offset(y: 3)
            }

            if let caption {
                Text(caption)
                    .font(.momoTrust(size: 8, weight: .regular))
                    .tracking(1.2)
                    .foregroundColor(Theme.textTertiary)
                    .padding(.top, 3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            text = value.map(String.init) ?? ""
            focused.wrappedValue = field
        }
        .onChange(of: isEditing) { _, editing in
            if !editing { commitTyped() }
        }
    }

    private func commitTyped() {
        let digits = text.filter(\.isNumber)
        if digits.isEmpty {
            value = nil
        } else {
            value = min(max(Int(digits) ?? range.lowerBound, range.lowerBound), range.upperBound)
        }
    }
}
