import KelloCore
import SwiftUI

/// Creates, edits or deletes one reminder, shown in place of the agenda inside the popover.
struct ReminderEditorView: View {
    @Environment(CalendarStore.self) private var calendars
    @State var draft: ReminderDraft
    let onClose: () -> Void

    @State private var confirmsDelete = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorHeader(
                title: draft.isNew ? "New Reminder" : "Edit Reminder",
                canSave: draft.canSave && !confirmsDelete,
                onBack: onClose,
                onSave: save)

            TextField("Title", text: $draft.title)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold))

            Divider()
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    label("List")
                    listPicker
                }
                GridRow {
                    label("Date")
                    HStack(spacing: 8) {
                        Toggle("", isOn: $draft.hasDueDate)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                        if draft.hasDueDate {
                            DatePicker("", selection: $draft.due, displayedComponents: [.date])
                                .labelsHidden()
                        }
                    }
                }
                if draft.hasDueDate {
                    GridRow {
                        label("Time")
                        HStack(spacing: 8) {
                            Toggle("", isOn: $draft.hasDueTime)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                            if draft.hasDueTime {
                                DatePicker("", selection: $draft.due, displayedComponents: [.hourAndMinute])
                                    .labelsHidden()
                            }
                        }
                    }
                }
                GridRow {
                    label("Priority")
                    Picker("", selection: $draft.priority) {
                        ForEach(ReminderPriority.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
            .font(.callout)

            Divider()
            TextField("Notes", text: $draft.notes, axis: .vertical)
                .lineLimit(2...6)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            if confirmsDelete {
                SpanConfirmation(message: "Delete this reminder?", isDestructive: true, asksForSpan: false,
                                 onConfirm: { _ in delete() }, onCancel: { confirmsDelete = false })
            } else if !draft.isNew {
                Button("Delete Reminder", role: .destructive) { confirmsDelete = true }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
        .onAppear {
            // Text fields only take typing while the app is active.
            NSApp.activate()
        }
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

    private func label(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
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
    var title: LocalizedStringKey {
        switch self {
        case .none: "None"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}
