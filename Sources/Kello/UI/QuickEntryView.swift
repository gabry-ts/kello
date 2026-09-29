import KelloCore
import SwiftUI

/// Adds an event from one typed line, shown in place of the agenda: the line in a large
/// field, then a live preview of the title, day, time and calendar. Return adds it.
struct QuickEntryView: View {
    let onClose: () -> Void
    /// Opens the full editor with what's been typed so far.
    let onEditDetails: (EventDraft) -> Void
    @State var text = ""
    @State var calendarID: String
    @Environment(CalendarStore.self) private var calendars
    @State private var entry: QuickEntry?
    @State private var errorMessage: String?
    @State private var isSaved = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            EditorHeader(title: "Quick Event", canSave: entry != nil && !calendarID.isEmpty, onBack: onClose, onSave: save)
            EditorTitleField(placeholder: "Dentist tomorrow at 3pm", text: $text, color: calendarColor)
                .onSubmit(save)
            if let entry {
                preview(entry)
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            } else {
                examples
                    .transition(.opacity)
            }
            if let errorMessage {
                EditorError(message: errorMessage)
            }
        }
        .animation(Theme.spring(reduceMotion), value: entry == nil)
        .onAppear {
            // Text fields only take typing while the app is active.
            NSApp.activate()
            parse()
        }
        .onChange(of: text) { parse() }
    }

    private var calendarColor: Color {
        calendars.eventCalendars.first { $0.id == calendarID }.map { Color($0.color) } ?? .accentColor
    }

    private func preview(_ entry: QuickEntry) -> some View {
        VStack(spacing: Theme.rowSpacing + 4) {
            FormCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title.isEmpty ? String(localized: "New Event") : entry.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(entry.title.isEmpty ? .secondary : .primary)
                        .lineLimit(2)
                    detail("calendar", Self.dayText(entry))
                    detail("clock", entry.isAllDay
                        ? String(localized: "All day")
                        : AgendaFormat.timeText(start: entry.start, end: entry.end, isAllDay: false, showsTimeZone: false))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                Hairline(leading: 10)
                FormRow("Calendar") { CalendarPicker(calendarID: $calendarID) }
            }
            HStack(spacing: 6) {
                Text("Press Return to add")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button("Edit Details…") { onEditDetails(entry.draft(calendarID: calendarID)) }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
            }
            .font(.system(size: 11))
            .padding(.horizontal, 3)
        }
    }

    private func detail(_ systemImage: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(calendarColor)
                .frame(width: 12)
            Text(text)
                .font(.system(size: 11.5))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    /// A few lines to type, while the field is empty.
    private var examples: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Type what and when, for example:")
                .foregroundStyle(.secondary)
            // Localized along with the parser's own words, so each language's examples parse.
            let examples = [
                String(localized: "Lunch with Sara friday 1pm"),
                String(localized: "Call Marco tomorrow 10:00-11:00"),
                String(localized: "Holiday 12 oct"),
            ]
            ForEach(examples, id: \.self) { example in
                Button { text = example } label: {
                    Label(example, systemImage: "wand.and.stars")
                        .labelStyle(ExampleLabelStyle())
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: 11.5))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .surface(radius: Theme.groupRadius, elevated: false)
    }

    private struct ExampleLabelStyle: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 6) {
                configuration.icon
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                configuration.title
                    .foregroundStyle(.primary)
            }
            .contentShape(.rect)
        }
    }

    /// "Wednesday, Sep 30", or the first and last day of a longer all-day entry.
    static func dayText(_ entry: QuickEntry) -> String {
        let calendar = Calendar.current
        if entry.isAllDay, !calendar.isDate(entry.start, inSameDayAs: entry.end),
           let end = calendar.date(byAdding: .day, value: 1, to: entry.end) {
            return AgendaFormat.timeText(start: entry.start, end: end, isAllDay: true)
        }
        return entry.start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func parse() {
        entry = QuickEntryParser.parse(text, now: .now)
    }

    /// Return in the field and the Save button can both fire; only the first one saves.
    private func save() {
        guard !isSaved, let entry, !calendarID.isEmpty else { return }
        do {
            try calendars.save(entry.draft(calendarID: calendarID), span: .thisEvent)
            isSaved = true
            onClose()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// The calendar menu of the event editors: writable calendars grouped by account, plus the
/// event's own calendar when it's read-only, so the picker always has a selection.
struct CalendarPicker: View {
    @Binding var calendarID: String
    @Environment(CalendarStore.self) private var calendars

    var body: some View {
        let writable = calendars.writableCalendars
        let options = writable.contains { $0.id == calendarID }
            ? writable
            : writable + calendars.eventCalendars.filter { $0.id == calendarID }
        Picker("", selection: $calendarID) {
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
}

/// The one-line field at the top of the new-event editor: typing "Dentist tomorrow at 3pm"
/// fills in the title, dates and all-day switch below as you go.
struct QuickEntryField: View {
    @Binding var draft: EventDraft
    @State private var text = ""

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 14)
            TextField("Quick entry, like “Lunch friday 1pm”", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .surface(radius: Theme.groupRadius, tint: .accentColor, tintAmount: 0.5, elevated: false)
        .onChange(of: text) {
            guard let entry = QuickEntryParser.parse(text, now: .now) else { return }
            draft.title = entry.title
            draft.isAllDay = entry.isAllDay
            draft.start = entry.start
            draft.end = entry.end
        }
    }
}
