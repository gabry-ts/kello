import KelloCore
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

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
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
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 10) {
                Button(action: onClose) {
                    GlassCircle(systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Back")
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("Search Events", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($isFocused)
                        .onSubmit(openFirst)
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear")
                    }
                }
                .padding(.horizontal, 11)
                .frame(height: Theme.controlSize)
                .glassEffect(.regular, in: .capsule)
                .glassEdge(Capsule())
            }
        }
        .frame(height: Theme.controlSize)
    }

    @ViewBuilder
    private var results: some View {
        if events == nil {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
        } else if EventMatcher(query: query).isEmpty {
            EmptyState(text: "Titles, locations and notes", systemImage: "magnifyingglass")
        } else {
            AgendaView(sections: sections, now: now, emptyText: "No Results", emptyImage: "magnifyingglass",
                       maxHeight: 440, openEvent: onSelect)
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
