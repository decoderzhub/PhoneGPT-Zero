import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            Text(message.content)
                .padding()
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
}
