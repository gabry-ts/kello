import AppKit
import EventKit
import KelloCore
import SwiftUI

/// Conversions from EventKit objects to KelloCore's plain values, done once at fetch time
/// so nothing past the store holds on to EventKit objects.
extension ItemColor {
    init(_ color: CGColor?) {
        let srgb = color.flatMap { NSColor(cgColor: $0)?.usingColorSpace(.sRGB) } ?? .systemGray
        self.init(red: Double(srgb.redComponent), green: Double(srgb.greenComponent), blue: Double(srgb.blueComponent))
    }
}

extension CalendarInfo {
    init(_ calendar: EKCalendar) {
        self.init(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            sourceTitle: calendar.source?.title ?? String(localized: "Other"),
            color: ItemColor(calendar.cgColor),
            isWritable: calendar.allowsContentModifications
        )
    }
}

extension CalendarEvent {
    init(_ event: EKEvent) {
        let url = event.url
        self.init(
            eventIdentifier: event.eventIdentifier ?? event.calendarItemIdentifier,
            calendarID: event.calendar?.calendarIdentifier ?? "",
            title: event.title?.isEmpty == false ? event.title : String(localized: "New Event"),
            start: event.startDate,
            end: event.isAllDay ? EKEvent.exclusiveAllDayEnd(event) : event.endDate,
            isAllDay: event.isAllDay,
            location: event.location,
            notes: event.notes,
            url: url,
            isRecurring: event.hasRecurrenceRules || event.isDetached,
            isDeclined: event.attendees?.first(where: \.isCurrentUser)?.participantStatus == .declined,
            isCancelled: event.status == .canceled,
            color: ItemColor(event.calendar?.cgColor),
            meetingURL: MeetingLink.find(in: [url?.absoluteString, event.location, event.notes])
        )
    }
}

extension ReminderItem {
    /// Nil for reminders without a due date, which the popover doesn't list.
    init?(_ reminder: EKReminder) {
        guard let components = reminder.dueDateComponents else { return nil }
        let calendar = components.calendar ?? Calendar.current
        let hasTime = components.hour != nil
        guard let date = calendar.date(from: components) else { return nil }
        self.init(
            id: reminder.calendarItemIdentifier,
            listID: reminder.calendar?.calendarIdentifier ?? "",
            title: reminder.title?.isEmpty == false ? reminder.title : String(localized: "New Reminder"),
            due: hasTime ? date : Calendar.current.startOfDay(for: date),
            hasDueTime: hasTime,
            notes: reminder.notes,
            priority: reminder.priority,
            color: ItemColor(reminder.calendar?.cgColor))
    }
}

extension EKEvent {
    /// All-day events end at 23:59:59 of their last day; KelloCore wants the midnight
    /// after it, like timed events' exclusive ends.
    static func exclusiveAllDayEnd(_ event: EKEvent) -> Date {
        let calendar = Calendar.current
        let lastDay = calendar.startOfDay(for: max(event.startDate, event.endDate.addingTimeInterval(-1)))
        return calendar.date(byAdding: .day, value: 1, to: lastDay) ?? event.endDate
    }

    var repeatOption: RepeatOption {
        guard let rules = recurrenceRules, !rules.isEmpty else { return .never }
        guard rules.count == 1, let rule = rules.first, rule.interval == 1, rule.recurrenceEnd == nil,
              rule.daysOfTheWeek == nil, rule.daysOfTheMonth == nil, rule.monthsOfTheYear == nil,
              rule.weeksOfTheYear == nil, rule.daysOfTheYear == nil, rule.setPositions == nil else { return .custom }
        switch rule.frequency {
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        case .yearly: return .yearly
        @unknown default: return .custom
        }
    }
}

extension RepeatOption {
    var frequency: EKRecurrenceFrequency? {
        switch self {
        case .daily: .daily
        case .weekly: .weekly
        case .monthly: .monthly
        case .yearly: .yearly
        case .never, .custom: nil
        }
    }
}

extension EventDraft {
    init(_ event: EKEvent) {
        let calendar = Calendar.current
        self.init(
            eventIdentifier: event.eventIdentifier,
            occurrenceStart: event.startDate,
            calendarID: event.calendar?.calendarIdentifier ?? "",
            title: event.title ?? "",
            isAllDay: event.isAllDay,
            start: event.startDate,
            end: event.isAllDay
                ? calendar.date(byAdding: .day, value: -1, to: EKEvent.exclusiveAllDayEnd(event)) ?? event.startDate
                : event.endDate,
            location: event.location ?? "",
            url: event.url?.absoluteString ?? "",
            notes: event.notes ?? "",
            alert: AlertOption(alarmOffsets: (event.alarms ?? []).map { $0.absoluteDate == nil ? $0.relativeOffset : nil }),
            repeatRule: event.repeatOption,
            wasRecurring: event.hasRecurrenceRules,
            isReadOnly: event.calendar?.allowsContentModifications == false
        )
    }

    /// For the snapshot store, which has no EventKit objects.
    init(sample event: CalendarEvent) {
        self.init(
            eventIdentifier: event.eventIdentifier, occurrenceStart: event.start, calendarID: event.calendarID,
            title: event.title, isAllDay: event.isAllDay, start: event.start, end: event.end,
            location: event.location ?? "", url: event.url?.absoluteString ?? "", notes: event.notes ?? "",
            repeatRule: event.isRecurring ? .weekly : .never, wasRecurring: event.isRecurring)
    }
}

extension Color {
    init(_ color: ItemColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue)
    }
}
