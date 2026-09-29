import Foundation

/// An extra time zone shown as a clock, with an optional label in place of its city.
public struct WorldClockZone: Codable, Hashable, Sendable, Identifiable {
    public var id: String { identifier }
    /// A `TimeZone` identifier, e.g. "America/New_York".
    public var identifier: String
    /// Empty to show the city.
    public var label: String

    public init(identifier: String, label: String = "") {
        self.identifier = identifier
        self.label = label
    }

    public var displayName: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? WorldClock.cityName(for: identifier) : trimmed
    }
}

/// What a clock shows: its name, the time there, how many days it's ahead of or behind
/// here, and whether it's daytime there.
public struct WorldClockReading: Hashable, Sendable {
    public let name: String
    public let time: String
    public let dayOffset: Int
    public let isDaytime: Bool

    /// "+1" or "−1", nil on the same day.
    public var dayOffsetText: String? {
        dayOffset == 0 ? nil : (dayOffset > 0 ? "+\(dayOffset)" : "\u{2212}\(-dayOffset)")
    }
}

public enum WorldClock {
    /// "New York" for "America/New_York", "Buenos Aires" for "America/Argentina/Buenos_Aires".
    public static func cityName(for identifier: String) -> String {
        (identifier.split(separator: "/").last.map(String.init) ?? identifier).replacingOccurrences(of: "_", with: " ")
    }

    /// Daytime runs from 6:00 to 18:00 local to the zone.
    public static func reading(for zone: WorldClockZone, now: Date, here: TimeZone = .current,
                               is24Hour: Bool? = nil, locale: Locale = .current) -> WorldClockReading {
        let there = TimeZone(identifier: zone.identifier) ?? here
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = there
        let hour = calendar.component(.hour, from: now)
        return WorldClockReading(
            name: zone.displayName,
            time: time(now, in: there, is24Hour: is24Hour, locale: locale),
            dayOffset: dayOffset(now, from: here, to: there),
            isDaytime: (6..<18).contains(hour))
    }

    /// The time in `zone`, in the locale's clock unless `is24Hour` says which.
    public static func time(_ date: Date, in zone: TimeZone, is24Hour: Bool? = nil, locale: Locale = .current) -> String {
        var components = Locale.Components(locale: locale)
        if let is24Hour {
            components.hourCycle = is24Hour ? .zeroToTwentyThree : .oneToTwelve
        }
        let style = Date.FormatStyle(locale: Locale(components: components), calendar: Calendar(identifier: .gregorian), timeZone: zone)
            .hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits)
        return date.formatted(style)
    }

    /// The zone's calendar day minus ours: 1 when it's already tomorrow there.
    public static func dayOffset(_ date: Date, from here: TimeZone, to there: TimeZone) -> Int {
        func day(in zone: TimeZone) -> Date? {
            var local = Calendar(identifier: .gregorian)
            local.timeZone = zone
            var utc = Calendar(identifier: .gregorian)
            utc.timeZone = TimeZone(identifier: "UTC")!
            return utc.date(from: local.dateComponents([.year, .month, .day], from: date))
        }
        guard let a = day(in: here), let b = day(in: there) else { return 0 }
        return Int((b.timeIntervalSince(a) / 86400).rounded())
    }

    /// "NYC 3:33 PM", appended to the menu bar title.
    public static func menuBarText(for zone: WorldClockZone, now: Date, is24Hour: Bool, locale: Locale = .current) -> String {
        let there = TimeZone(identifier: zone.identifier) ?? .current
        return "\(zone.displayName) \(time(now, in: there, is24Hour: is24Hour, locale: locale))"
    }

    /// Time zone identifiers whose city, region, identifier, localized name or
    /// abbreviation contains every word of `query`, ignoring case and accents, by city.
    public static func search(_ query: String, in identifiers: [String] = TimeZone.knownTimeZoneIdentifiers,
                              locale: Locale = .current) -> [String] {
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return identifiers
            .filter { identifier in
                guard !terms.isEmpty else { return true }
                let zone = TimeZone(identifier: identifier)
                let fields = [
                    identifier.replacingOccurrences(of: "_", with: " "),
                    zone?.localizedName(for: .generic, locale: locale),
                    zone?.localizedName(for: .standard, locale: locale),
                    zone?.abbreviation(),
                ].compactMap { $0 }
                return terms.allSatisfy { term in fields.contains { $0.range(of: term, options: options) != nil } }
            }
            .sorted { cityName(for: $0).localizedStandardCompare(cityName(for: $1)) == .orderedAscending }
    }
}
