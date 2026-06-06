import Foundation
import SwiftData

/// Something the pet should remind you about. Backed by a scheduled local
/// notification (`notificationID`); when it fires, the pet delivers it with a
/// speech bubble too.
@Model
final class Reminder {
    var title: String
    var dueDate: Date
    var isDelivered: Bool
    var notificationID: String

    init(title: String, dueDate: Date) {
        self.title = title
        self.dueDate = dueDate
        isDelivered = false
        notificationID = UUID().uuidString
    }

    var isOverdue: Bool {
        !isDelivered && dueDate < Date()
    }
}
