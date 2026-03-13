import SwiftUI

struct WordListView: View {
    let words: [Word]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(words) { word in
                    HStack(spacing: 12) {
                        Image(systemName: word.isFound ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(word.isFound ? word.highlightStyle.displayColor : .secondary)

                        Text(word.value)
                            .font(.body.weight(word.isFound ? .semibold : .regular))
                            .strikethrough(word.isFound, color: word.highlightStyle.displayColor)
                            .foregroundStyle(word.isFound ? word.highlightStyle.displayColor : .primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(uiColor: .systemBackground))
                    )
                }
            }
            .padding(2)
        }
        .dynamicTypeSize(.xSmall ... .accessibility3)
    }
}
