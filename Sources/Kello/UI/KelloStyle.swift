import PartitiUI
import SwiftUI

/// Kello's own measures and colors, for what Partiti UI leaves to each app: the month
/// grid, the fixed agenda height and the clocks.
enum KelloStyle {
    /// The agenda and reminders under the grid, fixed so the popover keeps one height.
    static let listHeight: CGFloat = 300

    // MARK: Grid

    static let cellHeight: CGFloat = 27
    static let dayCircle: CGFloat = 20
    static let dotSize: CGFloat = 3
    static let weekNumberWidth: CGFloat = 16

    // MARK: Colors

    /// The sun on the extra clocks.
    static func daytime(_ scheme: ColorScheme) -> Color { PUI.legible(Ink(scheme).orange, scheme) }
    /// The moon on the extra clocks.
    static func nighttime(_ scheme: ColorScheme) -> Color { PUI.legible(.indigo, scheme) }
    /// Holiday numbers in the grid and the holiday labels above a day's agenda.
    static func holiday(_ scheme: ColorScheme) -> Color { Ink(scheme).red }
}
