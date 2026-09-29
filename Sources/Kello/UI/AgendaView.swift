import KelloCore
import SwiftUI

/// The scrolling list under the grid: an optional "Next up" card, then sections with a
/// centered header, then their reminders, events and the "now" marker. Grows with its
/// content up to `maxHeight`, then scrolls.
struct AgendaView: View {
    let sections: [AgendaSection]
    let now: Date
    var nextUp: CalendarEvent?
    var emptyText: LocalizedStringKey = "No Events"
    var maxHeight: CGFloat = 300
    var openEvent: (CalendarEvent) -> Void = { _ in }
    var openReminder: (ReminderItem) -> Void = { _ in }
    var completeReminder: (ReminderItem) -> Void = { _ in }
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        if sections.isEmpty && nextUp == nil {
            Text(emptyText)
                .font(.callout)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if let nextUp {
                        NextUpCard(event: nextUp, now: now) { openEvent(nextUp) }
                    }
                    ForEach(sections) { section in
                        SectionHeader(title: section.title, count: section.title == Agenda.overdueTitle ? section.entries.count : nil)
                        ForEach(section.entries) { entry in
                            row(entry)
                        }
                    }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.automatic)
            .frame(height: min(max(contentHeight, 1), maxHeight))
        }
    }

    @ViewBuilder
    private func row(_ entry: AgendaEntry) -> some View {
        switch entry {
        case .event(let event):
            EventRow(event: event, now: now) { openEvent(event) }
        case .reminder(let reminder):
            ReminderRow(reminder: reminder, now: now, onComplete: { completeReminder(reminder) }) { openReminder(reminder) }
        case .now(let untilNext):
            NowMarker(untilNext: untilNext)
        }
    }
}

/// "Today", centered between two hairlines, with an optional count badge.
struct SectionHeader: View {
    let title: String
    var count: Int?

    var body: some View {
        HStack(spacing: 8) {
            line
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .fixedSize()
            if let count {
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .background(.red, in: .capsule)
            }
            line
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    private var line: some View {
        Rectangle()
            .fill(.primary.opacity(0.12))
            .frame(height: 1)
    }
}
