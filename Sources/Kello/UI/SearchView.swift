import KelloCore
import PartitiUI
import SwiftUI

/// Searches events of visible calendars from a year ago to two years ahead, shown in place
/// of the grid and agenda: a field at the top, then the matches grouped by day. Return
/// opens the first match.
struct SearchView: View {
    let now: Date
    let onClose: () -> Void
    let onSelect: (CalendarEvent) -> Void
    /// Starts with this text, for snapshots.
    var initialQuery = ""
    @Environment(SettingsStore.self) private var store
    @Environment(CalendarStore.self) private var calendars
    @State private var query = ""
    /// Nil until the events are fetched.
    @State private var events: [CalendarEvent]?
    @State private var sections: [AgendaSection] = []
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: PUI.Popover.cardGap) {
            header
            results
        }
        .onAppear {
            query = initialQuery
            // Text fields only take typing while the app is active.
            NSApp.activate()
            isFocused = true
        }
        .task(id: calendars.revision) {
            let hidden = store.settings.hiddenCalendarIDs
            events = await calendars.searchableEvents(now: now).filter { !hidden.contains($0.calendarID) }
            search()
        }
        .task(id: query) {
            // Waits for a pause in typing before searching.
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            search()
        }
    }

    private var header: some View {
        let ink = Ink(colorScheme)
        return HStack(spacing: PUI.Space.m) {
            GlassCircleButton("chevron.left", action: onClose)
                .keyboardShortcut(.cancelAction)
                .help("Back")
            HStack(spacing: PUI.Space.s) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(ink.secondary)
                TextField("Search Events", text: $query)
                    .textFieldStyle(.plain)
                    .font(PUI.Font.callout)
                    .focused($isFocused)
                    .onSubmit(openFirst)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(ink.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear")
                }
            }
            .padding(.horizontal, PUI.Space.m + 1)
            .frame(height: PUI.Control.small)
            .puiGlass(Capsule())
        }
        .frame(height: PUI.Control.small)
    }

    @ViewBuilder
    private var results: some View {
        if events == nil {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .padding(.vertical, PUI.Space.xl)
        } else if EventMatcher(query: query).isEmpty {
            EmptyState(symbol: "magnifyingglass", title: String(localized: "Search Events"),
                       message: String(localized: "Titles, locations and notes"))
        } else {
            AgendaView(sections: sections, now: now,
                       empty: .init(title: String(localized: "No Results"), message: String(localized: "Try another word."),
                                    symbol: "magnifyingglass"),
                       maxHeight: 400, openEvent: onSelect)
        }
    }

    private func search() {
        let matcher = EventMatcher(query: query)
        sections = matcher.isEmpty ? [] : matcher.sections(in: events ?? [], now: now)
    }

    private func openFirst() {
        guard case .event(let event) = sections.first?.entries.first else { return }
        onSelect(event)
    }
}
