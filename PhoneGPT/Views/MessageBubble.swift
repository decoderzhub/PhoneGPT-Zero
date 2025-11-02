import SwiftUI

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 0) {
                Text(renderMarkdown(message.content))
                    .padding()
            }
            .background(
                message.role == .user
                    ? Color.blue
                    : Color(UIColor.secondarySystemBackground)
            )
            .foregroundColor(message.role == .user ? .white : .primary)
            .cornerRadius(16)
            .contextMenu {
                Button(action: {
                    UIPasteboard.general.string = message.content
                }) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }

            if message.role == .assistant {
                Spacer()
            }
        }
    }

    private func renderMarkdown(_ text: String) -> AttributedString {
        do {
            var attributedString = try AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))

            for run in attributedString.runs {
                if run.inlinePresentationIntent?.contains(.code) == true {
                    attributedString[run.range].font = .monospaced(.body)()
                    attributedString[run.range].backgroundColor = Color(UIColor.tertiarySystemBackground)
                }
                if run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
                    attributedString[run.range].font = .body.bold()
                }
                if run.inlinePresentationIntent?.contains(.emphasized) == true {
                    attributedString[run.range].font = .body.italic()
                }
            }

            return attributedString
        } catch {
            return AttributedString(text)
        }
    }
}
