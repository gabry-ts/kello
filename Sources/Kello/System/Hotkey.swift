import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Opens or closes the popover from anywhere. Unset until the user records one, so it
    /// never takes over a shortcut another app relies on.
    static let togglePopover = Self("togglePopover")
}

/// The global shortcuts Kello listens for, recorded in General settings.
@MainActor
enum Hotkey {
    static func register(togglePopover: @escaping @MainActor () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .togglePopover) {
            MainActor.assumeIsolated { togglePopover() }
        }
    }
}
