import AppKit
import Observation
import SwiftUI

/// State shared between the popover's content and its controller.
@MainActor
@Observable
final class PopoverState {
    /// A pinned popover stays open when clicking elsewhere, until closed from the menu bar.
    var isPinned = false
}

/// The menu bar item and its popover. Managed directly instead of through MenuBarExtra,
/// which does not reliably redraw its label, so the title updates on every change.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let makeContent: () -> AnyView
    private let render: () -> String
    private let state: PopoverState
    private var shown: String?
    private var minuteTimer: Timer?

    /// The popover's view is built on open and dropped on close, so nothing in it keeps
    /// running while it's hidden.
    init(state: PopoverState, content: @escaping () -> AnyView, render: @escaping () -> String) {
        self.state = state
        self.makeContent = content
        self.render = render
        super.init()
        popover.delegate = self
        popover.animates = true
        item.button?.target = self
        item.button?.action = #selector(toggle)
        refresh()
        trackPin()
        scheduleMinuteTimer()
    }

    func closePopover() {
        popover.performClose(nil)
    }

    /// Draws the title and re-arms tracking, so any change to what it reads (settings, in
    /// later batches) triggers the next draw.
    private func refresh() {
        let title = withObservationTracking {
            render()
        } onChange: { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        guard let button = item.button else { return }
        // Rebuilding the title only when it changes avoids needless relayout.
        guard title != shown else { return }
        shown = title
        button.title = title
        button.setAccessibilityLabel("Kello")
    }

    private func trackPin() {
        let pinned = withObservationTracking {
            state.isPinned
        } onChange: { [weak self] in
            Task { @MainActor in self?.trackPin() }
        }
        popover.behavior = pinned ? .applicationDefined : .transient
    }

    /// Realigns to the next minute boundary so the clock never drifts, then re-fires every
    /// 60 seconds from there.
    private func scheduleMinuteTimer() {
        let now = Date()
        let nextMinute = Calendar.current.nextDate(after: now, matching: DateComponents(second: 0), matchingPolicy: .nextTime)
            ?? now.addingTimeInterval(60)
        minuteTimer?.invalidate()
        minuteTimer = Timer.scheduledTimer(withTimeInterval: nextMinute.timeIntervalSince(now), repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
                self?.scheduleMinuteTimer()
            }
        }
    }

    @objc private func toggle() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    /// Opens or closes the popover from the global shortcut. The app is activated first,
    /// since nothing else made it frontmost, so the popover takes keyboard focus.
    func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate()
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = item.button else { return }
        let host = NSHostingController(rootView: makeContent())
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidClose(_ notification: Notification) {
        popover.contentViewController = nil
    }
}
