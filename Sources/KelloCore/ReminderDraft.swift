import Foundation

/// A reminder's priority, on EventKit's 0 (none), 1 (high) ... 9 (low) scale.
public enum ReminderPriority: Int, Hashable, Sendable, CaseIterable {
    case none = 0
    case high = 1
    case medium = 5
    case low = 9

    /// EventKit allows any value from 1 to 9; they're bucketed the way Reminders does.
    public init(eventKitValue: Int) {
        switch eventKitValue {
        case 1...4: self = .high
        case 5: self = .medium
        case 6...9: self = .low
        default: self = .none
        }
    }
}

/// A reminder being created or edited, free of EventKit types.
public struct ReminderDraft: Hashable, Sendable {
    /// Nil for a new reminder.
    public var id: String?
    public var listID: String
    public var title: String
    public var hasDueDate: Bool
    public var hasDueTime: Bool
    public var due: Date
    public var notes: String
    public var priority: ReminderPriority

    public init(
        id: String? = nil,
        listID: String,
        title: String = "",
        hasDueDate: Bool = true,
        hasDueTime: Bool = false,
        due: Date,
        notes: String = "",
        priority: ReminderPriority = .none
    ) {
        self.id = id
        self.listID = listID
        self.title = title
        self.hasDueDate = hasDueDate
        self.hasDueTime = hasDueTime
        self.due = due
        self.notes = notes
        self.priority = priority
    }

    public var isNew: Bool { id == nil }

    /// A reminder due on `day`, without a time.
    public static func new(on day: Date, listID: String, calendar: Calendar = .current) -> ReminderDraft {
        ReminderDraft(listID: listID, due: calendar.startOfDay(for: day))
    }

    public init(_ reminder: ReminderItem, calendar: Calendar = .current) {
        self.init(
            id: reminder.id,
            listID: reminder.listID,
            title: reminder.title,
            hasDueDate: reminder.due != nil,
            hasDueTime: reminder.hasDueTime,
            due: reminder.due ?? calendar.startOfDay(for: .now),
            notes: reminder.notes ?? "",
            priority: ReminderPriority(eventKitValue: reminder.priority))
    }

    public var canSave: Bool {
        !listID.isEmpty && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The due date as calendar components: a date only, or with hour and minute.
    public func dueComponents(calendar: Calendar = .current) -> DateComponents? {
        guard hasDueDate else { return nil }
        let units: Set<Calendar.Component> = hasDueTime ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
        var components = calendar.dateComponents(units, from: due)
        components.calendar = calendar
        components.timeZone = hasDueTime ? calendar.timeZone : nil
        return components
    }
}
