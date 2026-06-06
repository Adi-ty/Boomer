import SwiftUI

/// Chat with your pet. Custom bubble rows (system semantic colors — adapts to
/// dark mode); the pet's replies stream in live.
struct ChatView: View {
    let ai: AIService
    let engine: PetEngine

    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header

            if case let .unavailable(why) = ai.state {
                unavailableBanner(why)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if ai.messages.isEmpty { emptyHint }
                        ForEach(ai.messages) { message in
                            row(for: message).id(message.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: ai.messages) {
                    if let last = ai.messages.last?.id {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }

            inputBar
        }
        .frame(width: 380, height: 500)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Text("Chat with \(engine.pet.name)")
                .font(.headline)
            Spacer()
            Button("Summarize clipboard", systemImage: "doc.on.clipboard") {
                ai.summarizeClipboard()
            }
            .labelStyle(.iconOnly)
            .help("Summarize whatever text is on the clipboard")
            Button("Clear", systemImage: "trash") {
                ai.clearConversation()
            }
            .labelStyle(.iconOnly)
            .help("Clear the conversation")
            .disabled(ai.messages.isEmpty)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func unavailableBanner(_ why: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "brain")
                .foregroundStyle(.secondary)
            Text(why)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.5))
    }

    private var emptyHint: some View {
        VStack(spacing: 6) {
            Text(engine.pet.species == .dog ? "🐶" : "🐱").font(.system(size: 40))
            Text("Say hi to \(engine.pet.name)!")
                .foregroundStyle(.secondary)
            Text("Try: “remind me to stretch in 20 minutes”")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    @ViewBuilder
    private func row(for message: ChatMessage) -> some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 50)
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.tint.opacity(0.9)))
                    .foregroundStyle(.white)
            }
        case .pet:
            HStack(alignment: .bottom, spacing: 6) {
                Text(engine.pet.species == .dog ? "🐶" : "🐱")
                if message.text.isEmpty {
                    ProgressView().controlSize(.small).padding(6)
                } else {
                    Text(message.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.quaternary.opacity(0.6)))
                        .textSelection(.enabled)
                }
                Spacer(minLength: 50)
            }
        case .system:
            Text(message.text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Say something to \(engine.pet.name)…", text: $draft)
                .textFieldStyle(.roundedBorder)
                .focused($inputFocused)
                .onSubmit(send)
            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 22))
            }
            .buttonStyle(.borderless)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || ai.isResponding)
        }
        .padding(12)
        .background(.bar)
        .onAppear { inputFocused = true }
    }

    private func send() {
        ai.send(draft)
        draft = ""
    }
}
