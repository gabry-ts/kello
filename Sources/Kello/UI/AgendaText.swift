import Foundation
import KelloCore

/// The app's own wording around KelloCore's formatted values.
extension AgendaFormat {
    /// `timeRange`, with an all-day event on a single day called "All day".
    static func timeText(start: Date, end: Date, isAllDay: Bool, showsTimeZone: Bool = true) -> String {
        timeRange(start: start, end: end, isAllDay: isAllDay, showsTimeZone: showsTimeZone) ?? String(localized: "All day")
    }

    /// How long ago a reminder was due, in its two largest units: "25d 23h ago", or "now"
    /// under a minute.
    static func overdueAge(since due: Date, now: Date) -> String {
        let seconds = now.timeIntervalSince(due)
        guard seconds >= 60 else { return String(localized: "now") }
        return String(localized: "\(compactDuration(seconds)) ago")
    }
}
