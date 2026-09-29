import Foundation
import KelloCore

/// Which list the popover shows under the grid.
enum ListTab: String, Codable, CaseIterable {
    case agenda
    case reminders
}

/// Everything persisted to disk, as JSON.
struct Settings: Codable, Hashable {
    var menuBar = MenuBarSettings()
    var firstWeekday = FirstWeekday.system
    var showWeekNumbers = false
    var agendaMode = AgendaMode.day
    var listTab = ListTab.agenda
    /// Calendars and reminder lists left out of the dots, the list and the counts.
    var hiddenCalendarIDs: Set<String> = []
    /// Whose events mark days as holidays in the grid, shown by name above that day's
    /// agenda instead of as events.
    var holidayCalendar = HolidayCalendarChoice.automatic
    /// Extra clocks shown in the popover, in order.
    var timeZones: [WorldClockZone] = []
    /// One of `timeZones` whose time follows the date in the menu bar.
    var menuBarTimeZone: String?
    /// Notifications shortly before meetings start.
    var meetingAlerts = MeetingAlertSettings()

    init() {}

    /// Missing keys fall back to defaults, so settings files from older versions still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        menuBar = try c.decodeIfPresent(MenuBarSettings.self, forKey: .menuBar) ?? d.menuBar
        firstWeekday = try c.decodeIfPresent(FirstWeekday.self, forKey: .firstWeekday) ?? d.firstWeekday
        showWeekNumbers = try c.decodeIfPresent(Bool.self, forKey: .showWeekNumbers) ?? d.showWeekNumbers
        agendaMode = try c.decodeIfPresent(AgendaMode.self, forKey: .agendaMode) ?? d.agendaMode
        listTab = try c.decodeIfPresent(ListTab.self, forKey: .listTab) ?? d.listTab
        hiddenCalendarIDs = try c.decodeIfPresent(Set<String>.self, forKey: .hiddenCalendarIDs) ?? d.hiddenCalendarIDs
        holidayCalendar = try c.decodeIfPresent(HolidayCalendarChoice.self, forKey: .holidayCalendar) ?? d.holidayCalendar
        timeZones = try c.decodeIfPresent([WorldClockZone].self, forKey: .timeZones) ?? d.timeZones
        menuBarTimeZone = try c.decodeIfPresent(String.self, forKey: .menuBarTimeZone) ?? d.menuBarTimeZone
        meetingAlerts = try c.decodeIfPresent(MeetingAlertSettings.self, forKey: .meetingAlerts) ?? d.meetingAlerts
    }

    func isCalendarVisible(_ id: String) -> Bool {
        !hiddenCalendarIDs.contains(id)
    }

    mutating func setCalendar(_ id: String, visible: Bool) {
        if visible { hiddenCalendarIDs.remove(id) } else { hiddenCalendarIDs.insert(id) }
    }

    /// The menu bar title: the date and time, then the chosen extra zone's time, if any.
    func menuBarTitle(now: Date) -> String {
        let title = MenuBarFormat.string(for: now, settings: menuBar)
        guard let id = menuBarTimeZone, let zone = timeZones.first(where: { $0.identifier == id }) else { return title }
        return "\(title) · \(WorldClock.menuBarText(for: zone, now: now, is24Hour: menuBar.is24Hour))"
    }

    mutating func removeTimeZone(_ identifier: String) {
        timeZones.removeAll { $0.identifier == identifier }
        if menuBarTimeZone == identifier { menuBarTimeZone = nil }
    }
}
