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
    }

    func isCalendarVisible(_ id: String) -> Bool {
        !hiddenCalendarIDs.contains(id)
    }

    mutating func setCalendar(_ id: String, visible: Bool) {
        if visible { hiddenCalendarIDs.remove(id) } else { hiddenCalendarIDs.insert(id) }
    }
}
