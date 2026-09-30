import Foundation

/// One part of the popover, shown in the order the user arranges them.
public enum PopoverSection: String, Codable, CaseIterable, Sendable {
    /// The month grid.
    case grid
    /// The Agenda and Reminders switch, with search, pin and new.
    case toolbar
    /// The overdue and today counts.
    case status
    /// The extra clocks, once time zones are set up.
    case clocks
    /// The card for today's next event.
    case nextUp
    /// The agenda or the reminders.
    case list

    /// Locked sections are always shown and keep their place: the grid on top, the
    /// toolbar right under it, since it drives the list, and the list at the bottom.
    public var isLocked: Bool {
        switch self {
        case .grid, .toolbar, .list: true
        case .status, .clocks, .nextUp: false
        }
    }
}

/// A section and whether it's shown.
public struct PopoverSectionItem: Codable, Hashable, Sendable, Identifiable {
    public var section: PopoverSection
    public var isOn: Bool

    public var id: PopoverSection { section }

    public init(_ section: PopoverSection, isOn: Bool = true) {
        self.section = section
        self.isOn = isOn
    }
}

/// What the popover shows, and in which order.
public struct PopoverLayout: Codable, Hashable, Sendable {
    /// Every section exactly once, in display order.
    public var items: [PopoverSectionItem] = PopoverLayout.defaultItems

    public static let defaultItems: [PopoverSectionItem] = [
        PopoverSectionItem(.grid),
        PopoverSectionItem(.toolbar),
        PopoverSectionItem(.status),
        PopoverSectionItem(.clocks),
        PopoverSectionItem(.nextUp),
        PopoverSectionItem(.list),
    ]

    public init() {}

    public init(items: [PopoverSectionItem]) {
        self.items = Self.normalized(items)
    }

    /// Items that are missing or can't be read fall back to the defaults, and the rest
    /// are repaired, whatever an older or hand-edited settings file holds.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let saved = (try? c.decodeIfPresent([PopoverSectionItem].self, forKey: .items)) ?? nil
        items = Self.normalized(saved ?? Self.defaultItems)
    }

    public func isOn(_ section: PopoverSection) -> Bool {
        items.first { $0.section == section }?.isOn ?? false
    }

    /// The sections that are switched on, in order.
    public var visibleSections: [PopoverSection] {
        items.filter(\.isOn).map(\.section)
    }

    /// Whether the Next up card sits right above the list, where it scrolls with it
    /// as the list's first card. Anywhere else it stands on its own.
    public var showsNextUpInList: Bool {
        let visible = visibleSections
        guard let index = visible.firstIndex(of: .nextUp) else { return false }
        return visible.indices.contains(index + 1) && visible[index + 1] == .list
    }

    /// Each section once: duplicates dropped, missing ones added as in the defaults,
    /// and the locked ones switched on and put back in their places.
    static func normalized(_ items: [PopoverSectionItem]) -> [PopoverSectionItem] {
        var seen = Set<PopoverSection>()
        var free = items.filter { !$0.section.isLocked && seen.insert($0.section).inserted }
        free.append(contentsOf: defaultItems.filter { !$0.section.isLocked && !seen.contains($0.section) })
        return [PopoverSectionItem(.grid), PopoverSectionItem(.toolbar)] + free + [PopoverSectionItem(.list)]
    }
}
