import Foundation

/// Shared design tokens. Window sizes live here so a view and the controller
/// that hosts it can never drift apart; spacing follows the macOS 4pt rhythm.
enum DS {
    // Spacing scale
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16

    // Window sizes (single source of truth for view frames + NSWindow rects)
    static let boardSize = CGSize(width: 360, height: 440)
    static let chatSize = CGSize(width: 380, height: 500)
    static let onboardingSize = CGSize(width: 560, height: 620)
}
