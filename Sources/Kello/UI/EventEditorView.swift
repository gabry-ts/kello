import EventKit
import KelloCore
import PartitiUI
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
    @Environment(\.puiAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: PUI.Popover.cardGap) {
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
        .animation(PUI.Motion.spring(reduceMotion: reduceMotion), value: pending)
        .animation(PUI.Motion.spring(reduceMotion: reduceMotion), value: draft.isAllDay)
        .onAppear {
            // Text fields only take typing while the app is active.
            NSApp.activate()
        }
    }

    private var selectedColor: Color {
        calendars.eventCalendars.first { $0.id == draft.calendarID }.map { Color($0.color) } ?? accent.color
    }

    private var fields: some View {
        VStack(spacing: PUI.Space.m) {
            FormCard {
                FormRow("Calendar") { CalendarPicker(calendarID: $draft.calendarID) }
                Hairline(leading: PUI.Space.l)
                FormRow("All-day") {
                    Toggle(String(localized: "All-day"), isOn: $draft.isAllDay)
                        .toggleStyle(PUISwitchStyle(mini: true, showsLabel: false))
                }
                Hairline(leading: PUI.Space.l)
                FormRow("Starts") {
                    DatePicker("", selection: startBinding, displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.field)
                }
                Hairline(leading: PUI.Space.l)
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
                Hairline(leading: PUI.Space.l)
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
                Hairline(leading: FormField.textLeading)
                FormField(systemImage: "link", placeholder: "URL", text: $draft.url)
                Hairline(leading: FormField.textLeading)
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

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: PUI.Space.m) {
            GlassCircleButton("chevron.left", action: onBack)
                .keyboardShortcut(.cancelAction)
                .help("Back")
            Text(title)
                .font(PUI.Font.headline)
                .foregroundStyle(Ink(colorScheme).primary)
            Spacer()
            if showsSave {
                Button("Save", action: onSave)
                    .buttonStyle(PrimaryButtonStyle(height: PUI.Control.small, fullWidth: false))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .frame(height: PUI.Control.small)
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
    @Environment(\.puiAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme

    private var color: Color { isDestructive ? Ink(colorScheme).red : accent.color }

    var body: some View {
        VStack(alignment: .leading, spacing: PUI.Space.m) {
            HStack(spacing: PUI.Space.s) {
                Image(systemName: isDestructive ? "trash" : "repeat")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PUI.legible(color, colorScheme))
                Text(message)
                    .font(PUI.Font.callout.weight(.semibold))
                    .foregroundStyle(Ink(colorScheme).primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // The two span buttons and Cancel don't fit on one line in the popover.
            VStack(alignment: .leading, spacing: PUI.Space.s) {
                if asksForSpan {
                    HStack(spacing: PUI.Space.s) {
                        confirm("This Event Only", span: .thisEvent)
                        confirm("All Future Events", span: .futureEvents)
                    }
                }
                HStack(spacing: PUI.Space.s) {
                    if !asksForSpan {
                        confirm(isDestructive ? "Delete" : "Save", span: .thisEvent)
                    }
                    Spacer(minLength: 0)
                    Button("Cancel", action: onCancel)
                        .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
                }
            }
        }
        .padding(PUI.Space.m + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .puiSurface(radius: PUI.Radius.group, tint: color, tintAmount: 0.7)
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
    }

    private func confirm(_ title: LocalizedStringKey, span: EKSpan) -> some View {
        Button(role: isDestructive ? .destructive : nil) { onConfirm(span) } label: { Text(title) }
            .buttonStyle(PrimaryButtonStyle(height: PUI.Control.small, fullWidth: false, color: isDestructive ? color : nil))
    }
}

// MARK: - Editor building blocks

/// The item's title, large, in its own card with the calendar or list color beside it.
struct EditorTitleField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    let color: Color

    var body: some View {
        HStack(spacing: PUI.Space.m) {
            Capsule()
                .fill(color)
                .frame(width: 3, height: 16)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(PUI.Font.headline)
        }
        .padding(.horizontal, PUI.Space.l)
        .frame(height: PUI.Control.large)
        .puiSurface(radius: PUI.Radius.group)
    }
}

/// A grouped section: rows stacked in one card, with hairlines placed between them.
struct FormCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .font(PUI.Font.callout)
        .controlSize(.small)
        .puiSurface(radius: PUI.Radius.group)
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

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: PUI.Space.m) {
            Text(label)
                .foregroundStyle(Ink(colorScheme).primary)
            Spacer(minLength: PUI.Space.s)
            control
        }
        .padding(.horizontal, PUI.Space.l)
        .frame(minHeight: PUI.Control.regular + 2)
    }
}

/// A borderless text field led by an icon, for the free-form fields at the bottom.
struct FormField: View {
    let systemImage: String
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var isMultiline = false
    @Environment(\.colorScheme) private var colorScheme

    /// Where the text starts, for the hairlines between fields.
    static let textLeading = PUI.Space.l + 12 + PUI.Space.m

    var body: some View {
        HStack(alignment: isMultiline ? .firstTextBaseline : .center, spacing: PUI.Space.m) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Ink(colorScheme).secondary)
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
        .padding(.horizontal, PUI.Space.l)
        .padding(.vertical, PUI.Space.s + 1)
        .frame(minHeight: PUI.Control.regular + 2)
    }
}

/// The delete action at the bottom of an editor, a quiet red row until pressed.
struct DeleteButton: View {
    let title: LocalizedStringKey
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(role: .destructive, action: action) {
            Label(title, systemImage: "trash")
                .font(PUI.Font.callout.weight(.medium))
                .foregroundStyle(Ink(colorScheme).red)
                .frame(maxWidth: .infinity)
                .frame(height: PUI.Control.regular + 2)
                .puiHoverHighlight(isHovered, radius: PUI.Radius.group)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .puiSurface(radius: PUI.Radius.group, elevated: false)
        .onHover { isHovered = $0 }
        .animation(PUI.Motion.hover, value: isHovered)
    }
}

/// A save or delete failure, in red under the fields.
struct EditorError: View {
    let message: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(PUI.Font.caption)
            .foregroundStyle(Ink(colorScheme).red)
            .padding(.horizontal, PUI.Space.xs)
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
