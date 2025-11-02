import SwiftUI

struct InputBar: View {
    @Binding var prompt: String
    @FocusState var isInputFocused: Bool
    var isLoading: Bool = false
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Ask anything...", text: $prompt, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(20)
                .focused($isInputFocused)
                .onSubmit {
                    if !isLoading && !prompt.isEmpty {
                        onSend()
                    }
                }

            Button(action: onSend) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }
            }
            .disabled(prompt.isEmpty || isLoading)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}
