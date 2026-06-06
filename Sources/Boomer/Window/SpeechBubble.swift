import SwiftUI

/// What the pet says, shown above its head. Fixed light bubble with dark ink
/// so it's readable over any wallpaper, in any system theme.
struct SpeechBubble: View {
    let text: String

    var body: some View {
        VStack(spacing: -1) {
            Text(text)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.22, green: 0.18, blue: 0.14))
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                )
            Triangle()
                .fill(.white)
                .frame(width: 14, height: 8)
                .rotationEffect(.degrees(180))
        }
        .frame(maxWidth: 210)
    }
}

/// Root view of the pet panel: the pet pinned to the bottom, with headroom
/// above for the speech bubble.
struct PetWindowRoot: View {
    let engine: PetEngine
    let motion: PetMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if let text = engine.announcement {
                SpeechBubble(text: text)
                    .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
            }
            PetView(engine: engine, motion: motion)
        }
        .frame(width: PetWindowController.size.width,
               height: PetWindowController.size.height,
               alignment: .bottom)
        .animation(.spring(duration: 0.3), value: engine.announcement)
    }
}
