import Foundation
import SwiftData
import Testing
@testable import Boomer

@MainActor
struct BoardModelsTests {
    @Test func notesPersistInContainer() throws {
        let service = try PersistenceService(inMemory: true)
        service.context.insert(Note(text: "hello"))
        service.context.insert(Note(text: "world"))
        let notes = try service.context.fetch(FetchDescriptor<Note>())
        #expect(notes.count == 2)
    }

    @Test func remindersRoundTripWithNotificationID() throws {
        let service = try PersistenceService(inMemory: true)
        let reminder = Reminder(title: "stretch", dueDate: Date().addingTimeInterval(600))
        service.context.insert(reminder)
        let fetched = try service.context.fetch(FetchDescriptor<Reminder>())
        #expect(fetched.first?.title == "stretch")
        #expect(fetched.first?.notificationID.isEmpty == false)
        #expect(fetched.first?.isDelivered == false)
    }

    @Test func reminderOverdueLogic() {
        let overdue = Reminder(title: "x", dueDate: Date(timeIntervalSinceNow: -60))
        #expect(overdue.isOverdue)
        overdue.isDelivered = true
        #expect(!overdue.isOverdue)

        let future = Reminder(title: "y", dueDate: Date(timeIntervalSinceNow: 600))
        #expect(!future.isOverdue)
    }
}
