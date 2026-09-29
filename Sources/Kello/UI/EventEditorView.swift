import EventKit
import KelloCore
import SwiftUI

/// Creates, edits or deletes one event, shown in place of the agenda inside the popover.
/// New events start with a quick entry line that fills in the fields. Saving or deleting a
/// recurring event asks, inline, whether to change this occurrence only or all future ones.
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

            if draft.isNew {
                QuickEntryField(draft: $draft)
            }

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
                FormRow("Calendar") { CalendarPicker(calendarID: $draft.calendarID) }
                Hairline(leading: 10)
                FormRow("All-day") {
                    Toggle("", isOn: $draft.isAllDay)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }
                Hairline(leading: 10)
                FormRow("Starts") {
                    DatePicker("", selection: startBinding, displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.field)
                }
                Hairline(leading: 10)
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
                Hairline(leading: 10)
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
                Hairline(leading: 30)
                FormField(systemImage: "link", placeholder: "URL", text: $draft.url)
                Hairline(leading: 30)
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
            HStack(spacing: 8) {
                Button(action: onBack) {
                    GlassCircle(systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Back")
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if showsSave {
                    Button(action: onSave) {
                        Text("Save")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 3)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: isDestructive ? "trash" : "repeat")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isDestructive ? Theme.destructive : Color.accentColor)
                Text(message)
                    .font(.system(size: 12, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            // The two span buttons and Cancel don't fit on one line in the popover.
            VStack(alignment: .leading, spacing: 6) {
                if asksForSpan {
                    HStack(spacing: 6) {
                        confirm("This Event Only", span: .thisEvent)
                        confirm("All Future Events", span: .futureEvents)
                    }
                }
                HStack(spacing: 6) {
                    if !asksForSpan {
                        confirm(isDestructive ? "Delete" : "Save", span: .thisEvent)
                    }
                    Spacer(minLength: 0)
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.glass)
                }
            }
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        }
        .padding(10)
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
        HStack(spacing: 8) {
            Capsule()
                .fill(color)
                .frame(width: 3, height: 16)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13.5, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
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
        .font(.system(size: 12))
        .controlSize(.small)
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
        HStack(spacing: 8) {
            Text(label)
                .foregroundStyle(.primary)
            Spacer(minLength: 6)
            control
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 30)
    }
}

/// A borderless text field led by an icon, for the free-form fields at the bottom.
struct FormField: View {
    let systemImage: String
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var isMultiline = false

    var body: some View {
        HStack(alignment: isMultiline ? .firstTextBaseline : .center, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 12)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: 30)
    }
}

/// The delete action at the bottom of an editor, a quiet red row until pressed.
struct DeleteButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Label(title, systemImage: "trash")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.destructive)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
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
            .font(.system(size: 11))
            .foregroundStyle(Theme.destructive)
            .padding(.horizontal, 3)
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
