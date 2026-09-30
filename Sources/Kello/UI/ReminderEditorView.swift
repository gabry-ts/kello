import KelloCore
import PartitiUI
import SwiftUI

/// Creates, edits or deletes one reminder, shown in place of the agenda inside the popover.
struct ReminderEditorView: View {
    @Environment(CalendarStore.self) private var calendars
    @State var draft: ReminderDraft
    let onClose: () -> Void

    @State private var confirmsDelete = false
    @State private var errorMessage: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.puiAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: PUI.Popover.cardGap) {
            EditorHeader(
                title: draft.isNew ? "New Reminder" : "Edit Reminder",
                canSave: draft.canSave && !confirmsDelete,
                onBack: onClose,
                onSave: save)

            EditorTitleField(placeholder: "Title", text: $draft.title, color: selectedColor)

            VStack(spacing: PUI.Space.m) {
                FormCard {
                    FormRow("List") { listPicker }
                    Hairline(leading: PUI.Space.l)
                    FormRow("Date") {
                        if draft.hasDueDate {
                            DatePicker("", selection: $draft.due, displayedComponents: [.date])
                                .labelsHidden()
                                .datePickerStyle(.field)
                        }
                        Toggle(String(localized: "Date"), isOn: $draft.hasDueDate)
                            .toggleStyle(PUISwitchStyle(mini: true, showsLabel: false))
                    }
                    if draft.hasDueDate {
                        Hairline(leading: PUI.Space.l)
                        FormRow("Time") {
                            if draft.hasDueTime {
                                DatePicker("", selection: $draft.due, displayedComponents: [.hourAndMinute])
                                    .labelsHidden()
                                    .datePickerStyle(.field)
                            }
                            Toggle(String(localized: "Time"), isOn: $draft.hasDueTime)
                                .toggleStyle(PUISwitchStyle(mini: true, showsLabel: false))
                        }
                    }
                }
                FormCard {
                    FormRow("Priority") {
                        Picker("", selection: $draft.priority) {
                            ForEach(ReminderPriority.allCases, id: \.self) { $0.title.tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                FormCard {
                    FormField(systemImage: "text.alignleft", placeholder: "Notes", text: $draft.notes, isMultiline: true)
                }
            }

            if let errorMessage {
                EditorError(message: errorMessage)
            }
            if confirmsDelete {
                SpanConfirmation(message: "Delete this reminder?", isDestructive: true, asksForSpan: false,
                                 onConfirm: { _ in delete() }, onCancel: { confirmsDelete = false })
            } else if !draft.isNew {
                DeleteButton(title: "Delete Reminder") { confirmsDelete = true }
            }
        }
        .animation(PUI.Motion.spring(reduceMotion: reduceMotion), value: confirmsDelete)
        .animation(PUI.Motion.spring(reduceMotion: reduceMotion), value: draft.hasDueDate)
        .animation(PUI.Motion.spring(reduceMotion: reduceMotion), value: draft.hasDueTime)
        .onAppear {
            // Text fields only take typing while the app is active.
            NSApp.activate()
        }
    }

    private var selectedColor: Color {
        calendars.reminderLists.first { $0.id == draft.listID }.map { Color($0.color) } ?? accent.color
    }

    private var listPicker: some View {
        Picker("", selection: $draft.listID) {
            ForEach(CalendarGroup.grouped(calendars.reminderLists.filter(\.isWritable))) { group in
                Section(group.sourceTitle) {
                    ForEach(group.calendars) { list in
                        Label { Text(list.title) } icon: { Image(nsImage: .swatch(list.color)) }
                            .tag(list.id)
                    }
                }
            }
        }
        .labelsHidden()
        .fixedSize()
    }

    private func save() {
        do {
            try calendars.save(draft)
            onClose()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() {
        do {
            try calendars.delete(draft)
            onClose()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension ReminderPriority {
    var title: Text {
        switch self {
        // A distinct key from the other "None" strings in the app: Italian needs the
        // feminine "Nessuna" here, agreeing with "priorità", not the masculine "Nessuno".
        case .none: Text(verbatim: String(localized: "reminderPriorityNone", defaultValue: "None"))
        case .low: Text("Low")
        case .medium: Text("Medium")
        case .high: Text("High")
        }
    }
}
