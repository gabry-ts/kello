import KelloCore
import PartitiUI
import SwiftUI

/// The scrolling list under the grid: an optional "Next up" card, then sections with a
/// header and the day's holidays, then their reminders (grouped in one card), events and
/// the "now" marker. Grows
/// with its content up to `maxHeight`, or keeps `fixedHeight`, then scrolls, fading out
/// at the bottom.
struct AgendaView: View {
    let sections: [AgendaSection]
    let now: Date
    var nextUp: CalendarEvent?
    var empty = Empty(title: String(localized: "No Events"), message: String(localized: "Nothing planned."), symbol: "calendar")
    var maxHeight: CGFloat = 320
    /// Keeps the list this tall whatever it holds, so the popover doesn't resize when
    /// switching tabs or days.
    var fixedHeight: CGFloat?
    var openEvent: (CalendarEvent) -> Void = { _ in }
    var openReminder: (ReminderItem) -> Void = { _ in }
    var completeReminder: (ReminderItem) -> Void = { _ in }
    @State private var contentHeight: CGFloat = 0

    /// What the list shows when there's nothing to list.
    struct Empty {
        let title: String
        let message: String
        let symbol: String
    }

    var body: some View {
        if sections.isEmpty && nextUp == nil {
            EmptyState(symbol: empty.symbol, title: empty.title, message: empty.message)
                .frame(height: fixedHeight, alignment: .top)
        } else {
            let scrolls = contentHeight > (fixedHeight ?? maxHeight)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let nextUp {
                        NextUpCard(event: nextUp, now: now) { openEvent(nextUp) }
                            .padding(.bottom, PUI.Space.xxs)
                    }
                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        AgendaSectionHeader(
                            title: section.isOverdue ? String(localized: "Overdue") : section.title,
                            detail: Self.detail(section),
                            badge: section.isOverdue ? section.entries.count : nil,
                            isFirst: index == 0 && nextUp == nil)
                        if !section.holidays.isEmpty {
                            HolidayLabels(names: section.holidays)
                                .padding(.bottom, section.entries.isEmpty ? 0 : PUI.Space.s)
                        }
                        VStack(spacing: PUI.Popover.rowGap) {
                            ForEach(Self.blocks(section.entries)) { block in
                                blockView(block)
                            }
                        }
                    }
                }
                .padding(.bottom, scrolls ? PUI.Space.xl + PUI.Space.xs : PUI.Space.xxs)
                // Room for the cards' shadows, which the scroll view would otherwise clip.
                .padding(.horizontal, PUI.Space.xs)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.never)
            .frame(height: fixedHeight ?? min(max(contentHeight, 1), maxHeight), alignment: .top)
            .padding(.horizontal, -PUI.Space.xs)
            .mask {
                VStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(colors: [.black, .black.opacity(scrolls ? 0 : 1)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 28)
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

/// A day's header: Partiti UI's section header, with a red count for overdue
/// reminders or a quiet detail on the right.
struct AgendaSectionHeader: View {
    let title: String
    var detail: String?
    var badge: Int?
    var isFirst = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SectionHeader(title) {
            if let badge {
                Badge("\(badge)", color: Ink(colorScheme).red, style: .solid)
            } else if let detail {
                Text(detail).monospacedDigit()
            }
        }
        .padding(.horizontal, PUI.Space.xs)
        .padding(.top, isFirst ? PUI.Space.xxs : PUI.Space.l)
        .padding(.bottom, PUI.Space.s)
    }
}

/// A day's holidays under its header: small red capsules, one per holiday.
struct HolidayLabels: View {
    let names: [String]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let red = KelloStyle.holiday(colorScheme)
        VStack(alignment: .leading, spacing: PUI.Space.xs) {
            ForEach(names, id: \.self) { name in
                HStack(spacing: PUI.Space.xs) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 7.5, weight: .bold))
                    Text(name)
                        .font(PUI.Font.badge)
                        .lineLimit(1)
                }
                .foregroundStyle(PUI.legible(red, colorScheme))
                .padding(.horizontal, PUI.Space.s + 1)
                .frame(height: 16)
                .background(red.opacity(colorScheme == .dark ? 0.18 : 0.11), in: .capsule)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Holiday: \(name)")
            }
        }
        .padding(.horizontal, PUI.Space.xxs)
    }
}
