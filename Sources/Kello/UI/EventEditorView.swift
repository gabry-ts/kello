import EventKit
import KelloCore
import SwiftUI

/// Creates, edits or deletes one event, shown in place of the agenda inside the popover.
/// Saving or deleting a recurring event asks, inline, whether to change this occurrence
/// only or all future ones.
struct EventEditorView: View {
    @Environment(CalendarStore.self) private var calendars
    @State var draft: EventDraft
    let onClose: () -> Void

    private enum Pending { case save, delete }
    @State private var pending: Pending?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorHeader(
                title: draft.isNew ? "New Event" : (draft.isReadOnly ? "Event" : "Edit Event"),
                canSave: draft.canSave && pending == nil,
                showsSave: !draft.isReadOnly,
                onBack: onClose,
                onSave: requestSave)

            TextField("Title", text: $draft.title)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold))

            Divider()
            fields
                .disabled(draft.isReadOnly)

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            footer
        }
        .onAppear {
            // Text fields only take typing while the app is active.
            NSApp.activate()
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    label("Calendar")
                    calendarPicker
                }
                GridRow {
                    label("All-day")
                    Toggle("", isOn: $draft.isAllDay)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }
                GridRow {
                    label("Starts")
                    DatePicker("", selection: startBinding, displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute])
                        .labelsHidden()
                }
                GridRow {
                    label("Ends")
                    DatePicker("", selection: $draft.end, in: draft.start..., displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute])
                        .labelsHidden()
                }
                GridRow {
                    label("Alert")
                    Picker("", selection: $draft.alert) {
                        ForEach(AlertOption.allCases, id: \.self) { Text($0.title).tag($0) }
                        if draft.alert == .custom { Text(AlertOption.custom.title).tag(AlertOption.custom) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                GridRow {
                    label("Repeat")
                    Picker("", selection: $draft.repeatRule) {
                        ForEach(RepeatOption.allCases, id: \.self) { Text($0.title).tag($0) }
                        if draft.repeatRule == .custom { Text(RepeatOption.custom.title).tag(RepeatOption.custom) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
            .font(.callout)

            Divider()
            TextField("Location", text: $draft.location)
            TextField("URL", text: $draft.url)
            TextField("Notes", text: $draft.notes, axis: .vertical)
                .lineLimit(2...6)
        }
        .textFieldStyle(.roundedBorder)
    }

    /// Moving the start moves the end with it, keeping the duration.
    private var startBinding: Binding<Date> {
        Binding(
            get: { draft.start },
            set: { newStart in
                draft.end = draft.end.addingTimeInterval(newStart.timeIntervalSince(draft.start))
                draft.start = newStart
            })
    }

    private var calendarPicker: some View {
        let writable = calendars.writableCalendars
        // A read-only event's own calendar is listed too, so the picker has a selection.
        let options = writable.contains { $0.id == draft.calendarID }
            ? writable
            : writable + calendars.eventCalendars.filter { $0.id == draft.calendarID }
        return Picker("", selection: $draft.calendarID) {
            ForEach(CalendarGroup.grouped(options)) { group in
                Section(group.sourceTitle) {
                    ForEach(group.calendars) { calendar in
                        Label { Text(calendar.title) } icon: { Image(nsImage: .swatch(calendar.color)) }
                            .tag(calendar.id)
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

    @ViewBuilder
    private var footer: some View {
        if let pending {
            SpanConfirmation(
                message: pending == .delete ? "Delete this event?" : "Save changes to this repeating event?",
                isDestructive: pending == .delete,
                asksForSpan: draft.wasRecurring,
                onConfirm: { span in
                    self.pending = nil
                    pending == .delete ? delete(span: span) : save(span: span)
                },
                onCancel: { self.pending = nil })
        } else if !draft.isNew && !draft.isReadOnly {
            Button("Delete Event", role: .destructive) { pending = .delete }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .font(.callout)
        }
    }

    private func requestSave() {
        if draft.wasRecurring && !draft.isNew {
            pending = .save
        } else {
            save(span: .thisEvent)
        }
    }

    private func save(span: EKSpan) {
        do {
            try calendars.save(draft, span: span)
            onClose()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(span: EKSpan) {
        do {
            try calendars.delete(draft, span: span)
            onClose()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Back button, title and Save, at the top of the event and reminder editors.
struct EditorHeader: View {
    let title: LocalizedStringKey
    let canSave: Bool
    var showsSave = true
    let onBack: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.icon)
            .keyboardShortcut(.cancelAction)
            .help("Back")
            Text(title)
                .font(.headline)
            Spacer()
            if showsSave {
                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
    }
}

/// The inline confirmation shown before deleting, or before saving a repeating item: either
/// one confirm button, or a choice between this occurrence and all future ones.
struct SpanConfirmation: View {
    let message: LocalizedStringKey
    let isDestructive: Bool
    let asksForSpan: Bool
    let onConfirm: (EKSpan) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .font(.callout.weight(.medium))
            HStack(spacing: 6) {
                if asksForSpan {
                    confirm("This Event Only", span: .thisEvent)
                    confirm("All Future Events", span: .futureEvents)
                } else {
                    confirm(isDestructive ? "Delete" : "Save", span: .thisEvent)
                }
                Spacer()
                Button("Cancel", action: onCancel)
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(.primary.opacity(0.05), in: .rect(cornerRadius: 10, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func confirm(_ title: LocalizedStringKey, span: EKSpan) -> some View {
        Button(role: isDestructive ? .destructive : nil) { onConfirm(span) } label: { Text(title) }
            .buttonStyle(.borderedProminent)
            .tint(isDestructive ? .red : .accentColor)
    }
}

extension AlertOption {
    var title: LocalizedStringKey {
        switch self {
        case .none: "None"
        case .atTime: "At time of event"
        case .minutes5: "5 minutes before"
        case .minutes10: "10 minutes before"
        case .minutes15: "15 minutes before"
        case .minutes30: "30 minutes before"
        case .hour1: "1 hour before"
        case .custom: "Custom"
        }
    }
}

extension RepeatOption {
    var title: LocalizedStringKey {
        switch self {
        case .never: "Never"
        case .daily: "Every Day"
        case .weekly: "Every Week"
        case .monthly: "Every Month"
        case .yearly: "Every Year"
        case .custom: "Custom"
        }
    }
}
