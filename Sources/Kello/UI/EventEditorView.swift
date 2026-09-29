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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            EditorHeader(
                title: draft.isNew ? "New Event" : (draft.isReadOnly ? "Event" : "Edit Event"),
                canSave: draft.canSave && pending == nil,
                showsSave: !draft.isReadOnly,
                onBack: onClose,
                onSave: requestSave)

            EditorTitleField(placeholder: "Title", text: $draft.title, color: selectedColor)
                .disabled(draft.isReadOnly)

            fields
                .disabled(draft.isReadOnly)

            if let errorMessage {
                EditorError(message: errorMessage)
            }
            footer
        }
        .animation(Theme.spring(reduceMotion), value: pending)
        .animation(Theme.spring(reduceMotion), value: draft.isAllDay)
        .onAppear {
            // Text fields only take typing while the app is active.
            NSApp.activate()
        }
    }

    private var selectedColor: Color {
        calendars.eventCalendars.first { $0.id == draft.calendarID }.map { Color($0.color) } ?? .accentColor
    }

    private var fields: some View {
        VStack(spacing: Theme.rowSpacing + 4) {
            FormCard {
                FormRow("Calendar") { calendarPicker }
                Hairline(leading: 12)
                FormRow("All-day") {
                    Toggle("", isOn: $draft.isAllDay)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }
                Hairline(leading: 12)
                FormRow("Starts") {
                    DatePicker("", selection: startBinding, displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.field)
                }
                Hairline(leading: 12)
                FormRow("Ends") {
                    DatePicker("", selection: $draft.end, in: draft.start..., displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.field)
                }
            }
            FormCard {
                FormRow("Alert") {
                    Picker("", selection: $draft.alert) {
                        ForEach(AlertOption.allCases, id: \.self) { Text($0.title).tag($0) }
                        if draft.alert == .custom { Text(AlertOption.custom.title).tag(AlertOption.custom) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Hairline(leading: 12)
                FormRow("Repeat") {
                    Picker("", selection: $draft.repeatRule) {
                        ForEach(RepeatOption.allCases, id: \.self) { Text($0.title).tag($0) }
                        if draft.repeatRule == .custom { Text(RepeatOption.custom.title).tag(RepeatOption.custom) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
            FormCard {
                FormField(systemImage: "mappin.and.ellipse", placeholder: "Location", text: $draft.location)
                Hairline(leading: 36)
                FormField(systemImage: "link", placeholder: "URL", text: $draft.url)
                Hairline(leading: 36)
                FormField(systemImage: "text.alignleft", placeholder: "Notes", text: $draft.notes, isMultiline: true)
            }
        }
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
            DeleteButton(title: "Delete Event") { pending = .delete }
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
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 10) {
                Button(action: onBack) {
                    GlassCircle(systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Back")
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if showsSave {
                    Button(action: onSave) {
                        Text("Save")
                            .font(.system(size: 12.5, weight: .semibold))
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
                }
            }
        }
        .frame(height: Theme.controlSize)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: isDestructive ? "trash" : "repeat")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isDestructive ? Theme.destructive : Color.accentColor)
                Text(message)
                    .font(.system(size: 13, weight: .semibold))
            }
            HStack(spacing: 6) {
                if asksForSpan {
                    confirm("This Event Only", span: .thisEvent)
                    confirm("All Future Events", span: .futureEvents)
                } else {
                    confirm(isDestructive ? "Delete" : "Save", span: .thisEvent)
                }
                Spacer(minLength: 0)
                Button("Cancel", action: onCancel)
                    .buttonStyle(.glass)
            }
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(radius: Theme.groupRadius, tint: isDestructive ? Theme.destructive : .accentColor, tintAmount: 0.7)
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
    }

    private func confirm(_ title: LocalizedStringKey, span: EKSpan) -> some View {
        Button(role: isDestructive ? .destructive : nil) { onConfirm(span) } label: { Text(title).fontWeight(.semibold) }
            .buttonStyle(.glassProminent)
            .tint(isDestructive ? Theme.destructive : .accentColor)
    }
}

// MARK: - Editor building blocks

/// The item's title, large, in its own card with the calendar or list color beside it.
struct EditorTitleField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(color)
                .frame(width: 4, height: 22)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .semibold))
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .surface(radius: Theme.groupRadius)
    }
}

/// A grouped section: rows stacked in one card, with hairlines placed between them.
struct FormCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .font(.system(size: 13))
        .surface(radius: Theme.groupRadius)
    }
}

/// A label on the left and its control on the right.
struct FormRow<Control: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder var control: Control

    init(_ label: LocalizedStringKey, @ViewBuilder control: () -> Control) {
        self.label = label
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            control
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 38)
    }
}

/// A borderless text field led by an icon, for the free-form fields at the bottom.
struct FormField: View {
    let systemImage: String
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var isMultiline = false

    var body: some View {
        HStack(alignment: isMultiline ? .firstTextBaseline : .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Group {
                if isMultiline {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(2...6)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 38)
    }
}

/// The delete action at the bottom of an editor, a quiet red row until pressed.
struct DeleteButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Label(title, systemImage: "trash")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.destructive)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .surface(radius: Theme.groupRadius, elevated: false)
        .hoverHighlight(cornerRadius: Theme.groupRadius, opacity: 0.04)
    }
}

/// A save or delete failure, in red under the fields.
struct EditorError: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 12))
            .foregroundStyle(Theme.destructive)
            .padding(.horizontal, 4)
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
