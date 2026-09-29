import Foundation

/// One piece of the menu bar title, shown in the order the user arranges them.
public enum MenuBarComponent: String, Codable, CaseIterable, Sendable {
    case weekday
    case date
    case year
    case time
}

/// A component and whether it's shown.
public struct MenuBarItem: Codable, Hashable, Sendable, Identifiable {
    public var component: MenuBarComponent
    public var isOn: Bool

    public var id: MenuBarComponent { component }

    public init(_ component: MenuBarComponent, isOn: Bool) {
        self.component = component
        self.isOn = isOn
    }
}

/// What the menu bar title shows. The items are ignored once `customPattern` is set.
public struct MenuBarSettings: Codable, Hashable, Sendable {
    /// Every component exactly once, in display order.
    public var items: [MenuBarItem] = MenuBarSettings.defaultItems
    /// Month spelled out ("Sep") when true, numeric ("09") otherwise.
    public var showMonthName = true
    /// 24-hour clock when true, 12-hour with AM/PM otherwise.
    public var is24Hour = false
    /// A literal `DateFormatter` format, e.g. "EEE d MMM HH:mm", used exactly as written.
    /// Overrides the items when non-empty.
    public var customPattern = ""
    /// Point size of the title.
    public var textSize: Double = MenuBarSettings.defaultTextSize

    public static let defaultItems: [MenuBarItem] = [
        MenuBarItem(.weekday, isOn: true),
        MenuBarItem(.date, isOn: true),
        MenuBarItem(.year, isOn: false),
        MenuBarItem(.time, isOn: false),
    ]
    public static let defaultTextSize: Double = 12
    public static let textSizeRange: ClosedRange<Double> = 10...15

    public init() {}

    /// Missing keys fall back to defaults, and the items are repaired so each component
    /// appears once, whatever an older or hand-edited settings file holds.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = MenuBarSettings()
        items = Self.normalized(try c.decodeIfPresent([MenuBarItem].self, forKey: .items) ?? d.items)
        showMonthName = try c.decodeIfPresent(Bool.self, forKey: .showMonthName) ?? d.showMonthName
        is24Hour = try c.decodeIfPresent(Bool.self, forKey: .is24Hour) ?? d.is24Hour
        customPattern = try c.decodeIfPresent(String.self, forKey: .customPattern) ?? d.customPattern
        textSize = try c.decodeIfPresent(Double.self, forKey: .textSize) ?? d.textSize
    }

    public func isOn(_ component: MenuBarComponent) -> Bool {
        items.first { $0.component == component }?.isOn ?? false
    }

    public mutating func set(_ component: MenuBarComponent, isOn: Bool) {
        guard let index = items.firstIndex(where: { $0.component == component }) else { return }
        items[index].isOn = isOn
    }

    /// Drops duplicates and appends any missing component, switched off.
    static func normalized(_ items: [MenuBarItem]) -> [MenuBarItem] {
        var seen = Set<MenuBarComponent>()
        var result = items.filter { seen.insert($0.component).inserted }
        for component in MenuBarComponent.allCases where !seen.contains(component) {
            result.append(MenuBarItem(component, isOn: false))
        }
        return result
    }
}

/// Builds the menu bar title from `MenuBarSettings`: each shown component formatted on
/// its own, in the user's order, with names in the locale's language.
public enum MenuBarFormat {
    /// Shown when every component is off and no custom pattern is set, so the item never
    /// goes blank.
    public static let fallback = "Kello"

    public static func string(for date: Date, settings: MenuBarSettings, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        let pattern = settings.customPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pattern.isEmpty {
            return format(date, pattern, locale: locale, timeZone: timeZone)
        }

        let parts = settings.items.filter(\.isOn).map { item -> String in
            switch item.component {
            case .weekday:
                format(date, "EEE", locale: locale, timeZone: timeZone)
            case .date:
                // "30 Sep" like the macOS clock's short style; numeric dates follow the
                // locale's day and month order.
                settings.showMonthName
                    ? format(date, "d MMM", locale: locale, timeZone: timeZone)
                    : format(date, DateFormatter.dateFormat(fromTemplate: "ddMM", options: 0, locale: locale) ?? "dd/MM",
                             locale: locale, timeZone: timeZone)
            case .year:
                format(date, "yyyy", locale: locale, timeZone: timeZone)
            case .time:
                format(date, settings.is24Hour ? "HH:mm" : "h:mm a", locale: locale, timeZone: timeZone)
            }
        }
        let text = parts.joined(separator: " ")
        return text.isEmpty ? fallback : text
    }

    private static func format(_ date: Date, _ pattern: String, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
