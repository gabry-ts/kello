import Foundation
import KelloCore

/// Everything persisted to disk, as JSON.
struct Settings: Codable, Hashable {
    var menuBar = MenuBarSettings()
    var firstWeekday = FirstWeekday.system
    var showWeekNumbers = false
    var agendaMode = AgendaMode.day

    init() {}

    /// Missing keys fall back to defaults, so settings files from older versions still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        menuBar = try c.decodeIfPresent(MenuBarSettings.self, forKey: .menuBar) ?? d.menuBar
        firstWeekday = try c.decodeIfPresent(FirstWeekday.self, forKey: .firstWeekday) ?? d.firstWeekday
        showWeekNumbers = try c.decodeIfPresent(Bool.self, forKey: .showWeekNumbers) ?? d.showWeekNumbers
        agendaMode = try c.decodeIfPresent(AgendaMode.self, forKey: .agendaMode) ?? d.agendaMode
    }
}
