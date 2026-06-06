import Foundation
import SwiftData

/// A quick jot, kept by the pet.
@Model
final class Note {
    var text: String
    var createdAt: Date

    init(text: String, createdAt: Date = Date()) {
        self.text = text
        self.createdAt = createdAt
    }
}
