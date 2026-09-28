import AppKit
import Observation
import SwiftUI

/// The menu bar item and its popover. Managed directly instead of through MenuBarExtra,
/// which does not reliably redraw its label, so the title updates on every change.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let makeContent: () -> AnyView
    private let render: () -> String
    private var shown: String?
    private var minuteTimer: Timer?

    /// The popover's view is built on open and dropped on close, so nothing in it keeps
    /// running while it's hidden.
    init(content: @escaping () -> AnyView, render: @escaping () -> String) {
        self.makeContent = content
        self.render = render
        super.init()
        popover.delegate = self
        popover.behavior = .transient
        popover.animates = true
        item.button?.target = self
        item.button?.action = #selector(toggle)
        refresh()
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
        guard let button = item.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            let host = NSHostingController(rootView: makeContent())
            host.sizingOptions = .preferredContentSize
            popover.contentViewController = host
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        popover.contentViewController = nil
    }
}
