import SwiftData
import SwiftUI

/// The pet's clipboard: quick notes and reminders. Uses system semantic
/// colors throughout, so it adapts to light/dark mode.
struct BoardView: View {
    enum Tab: String, CaseIterable {
        case notes = "Notes"
        case reminders = "Reminders"
    }

    @State private var tab: Tab

    init(initialTab: Tab = .notes) {
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)

            switch tab {
            case .notes: NotesTab()
            case .reminders: RemindersTab()
            }
        }
        .frame(width: DS.boardSize.width, height: DS.boardSize.height)
    }
}

// MARK: - Notes

private struct NotesTab: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            TextField("Jot something down…", text: $draft)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .onSubmit(addNote)

            if notes.isEmpty {
                Spacer()
                ContentUnavailableView("No notes yet",
                                       systemImage: "pawprint",
                                       description: Text("Your pet will hold onto anything you jot down."))
                Spacer()
            } else {
                List {
                    ForEach(notes) { note in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(note.text)
                            Text(note.createdAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                context.delete(note)
                                try? context.save()
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            context.delete(notes[index])
                        }
                        try? context.save()
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .padding(.top, 2)
    }

    private func addNote() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        context.insert(Note(text: text))
        try? context.save() // autosave is unreliable for our manual container
        draft = ""
    }
}

// MARK: - Reminders

private struct RemindersTab: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Reminder.dueDate) private var reminders: [Reminder]
    @State private var draft = ""
    @State private var minutes = 15

    private let presets = [5, 15, 30, 60]

    var body: some View {
        VStack(spacing: 8) {
            TextField("Remind me to…", text: $draft)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .onSubmit(addReminder)

            HStack {
                Picker("In", selection: $minutes) {
                    ForEach(presets, id: \.self) { Text("\($0) min").tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Button("Add") { addReminder() }
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12)

            if reminders.isEmpty {
                Spacer()
                ContentUnavailableView("Nothing scheduled",
                                       systemImage: "bell",
                                       description: Text("Your pet will jump and tell you when it's time."))
                Spacer()
            } else {
                List {
                    ForEach(reminders) { reminder in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reminder.title)
                                    .strikethrough(reminder.isDelivered)
                                    .foregroundStyle(reminder.isDelivered ? .secondary : .primary)
                                if reminder.isDelivered {
                                    Text("Delivered").font(.caption2).foregroundStyle(.secondary)
                                } else {
                                    Text(reminder.dueDate, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(reminder.isOverdue ? .red : .secondary)
                                }
                            }
                            Spacer()
                            Button {
                                remove(reminder)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .padding(.top, 2)
    }

    private func addReminder() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        PermissionsManager.shared.requestNotificationsIfNeeded()
        let reminder = Reminder(title: title, dueDate: Date().addingTimeInterval(Double(minutes) * 60))
        context.insert(reminder)
        try? context.save()
        ReminderScheduler.schedule(title: title, at: reminder.dueDate, id: reminder.notificationID)
        draft = ""
    }

    private func remove(_ reminder: Reminder) {
        ReminderScheduler.cancel(id: reminder.notificationID)
        context.delete(reminder)
        try? context.save()
    }
}
