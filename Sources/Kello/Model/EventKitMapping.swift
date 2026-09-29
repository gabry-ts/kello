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
            end: event.endDate,
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

extension Color {
    init(_ color: ItemColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue)
    }
}
