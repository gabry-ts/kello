import KelloCore
import SwiftUI

/// The scrolling list under the grid: an optional "Next up" card, then sections with a
/// header and the day's holidays, then their reminders (grouped in one card), events and
/// the "now" marker. Grows
/// with its content up to `maxHeight`, then scrolls, fading out at the bottom.
struct AgendaView: View {
    let sections: [AgendaSection]
    let now: Date
    var nextUp: CalendarEvent?
    var emptyText: LocalizedStringKey = "No Events"
    var emptyImage = "calendar"
    var maxHeight: CGFloat = 320
    var openEvent: (CalendarEvent) -> Void = { _ in }
    var openReminder: (ReminderItem) -> Void = { _ in }
    var completeReminder: (ReminderItem) -> Void = { _ in }
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        if sections.isEmpty && nextUp == nil {
            EmptyState(text: emptyText, systemImage: emptyImage)
        } else {
            let scrolls = contentHeight > maxHeight
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let nextUp {
                        NextUpCard(event: nextUp, now: now) { openEvent(nextUp) }
                            .padding(.bottom, 4)
                    }
                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        SectionHeader(
                            title: section.isOverdue ? String(localized: "Overdue") : section.title,
                            detail: Self.detail(section),
                            badge: section.isOverdue ? section.entries.count : nil,
                            isFirst: index == 0 && nextUp == nil)
                        if !section.holidays.isEmpty {
                            HolidayLabels(names: section.holidays)
                                .padding(.bottom, section.entries.isEmpty ? 0 : 8)
                        }
                        VStack(spacing: Theme.rowSpacing) {
                            ForEach(Self.blocks(section.entries)) { block in
                                blockView(block)
                            }
                        }
                    }
                }
                .padding(.bottom, scrolls ? 24 : 2)
                // Room for the cards' shadows, which the scroll view would otherwise clip.
                .padding(.horizontal, 4)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.never)
            .frame(height: min(max(contentHeight, 1), maxHeight))
            .padding(.horizontal, -4)
            .mask {
                VStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(colors: [.black, .black.opacity(scrolls ? 0 : 1)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 36)
                }
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .reminders(let reminders):
            ReminderGroup(reminders: reminders, now: now, onComplete: completeReminder, onOpen: openReminder)
        case .event(let event):
            EventRow(event: event, now: now) { openEvent(event) }
        case .now(let untilNext):
            NowMarker(untilNext: untilNext)
        }
    }

    /// What a section's entries are drawn as: runs of reminders share one card.
    enum Block: Identifiable {
        case reminders([ReminderItem])
        case event(CalendarEvent)
        case now(untilNext: TimeInterval?)

        var id: String {
            switch self {
            case .reminders(let reminders): "r|\(reminders.first?.id ?? "")"
            case .event(let event): "e|\(event.id)"
            case .now: "now"
            }
        }
    }

    static func blocks(_ entries: [AgendaEntry]) -> [Block] {
        var blocks: [Block] = []
        for entry in entries {
            switch entry {
            case .reminder(let reminder):
                if case .reminders(let run) = blocks.last {
                    blocks[blocks.count - 1] = .reminders(run + [reminder])
                } else {
                    blocks.append(.reminders([reminder]))
                }
            case .event(let event):
                blocks.append(.event(event))
            case .now(let untilNext):
                blocks.append(.now(untilNext: untilNext))
            }
        }
        return blocks
    }

    /// "4 events" or "2 reminders", on the right of a day's header.
    private static func detail(_ section: AgendaSection) -> String? {
        guard !section.isOverdue else { return nil }
        var events = 0, reminders = 0
        for entry in section.entries {
            switch entry {
            case .event: events += 1
            case .reminder: reminders += 1
            case .now: break
            }
        }
        if events > 0 { return String(localized: "\(events) events") }
        if reminders > 0 { return String(localized: "\(reminders) reminders") }
        return nil
    }
}

/// "Today" on the left, an optional red count badge after it, and a quiet detail on the right.
struct SectionHeader: View {
    let title: String
    var detail: String?
    var badge: Int?
    var isFirst = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            if let badge {
                Text("\(badge)")
                    .font(.system(size: 10.5, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .frame(minWidth: 17, minHeight: 17)
                    .background(Theme.destructive, in: .capsule)
            }
            Spacer()
            if let detail {
                Text(detail)
                    .font(.system(size: 11.5))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, isFirst ? 2 : 14)
        .padding(.bottom, 8)
    }
}

/// A day's holidays under its header: small red capsules, one per holiday.
struct HolidayLabels: View {
    let names: [String]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(names, id: \.self) { name in
                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8.5, weight: .bold))
                    Text(name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.legible(Theme.holiday, colorScheme))
                .padding(.horizontal, 8)
                .frame(height: 20)
                .background(Theme.holiday.opacity(colorScheme == .dark ? 0.18 : 0.11), in: .capsule)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Holiday: \(name)")
            }
        }
        .padding(.horizontal, 2)
    }
}

/// What the list shows when there's nothing to list.
struct EmptyState: View {
    let text: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .surface(radius: Theme.groupRadius, elevated: false)
    }
}
