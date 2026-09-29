import KelloCore
import SwiftUI

/// Time Zones settings: the extra clocks, each with an optional label, reordered by
/// dragging or from its menu, and which one's time also shows in the menu bar.
struct TimeZonesSettingsView: View {
    @Environment(SettingsStore.self) private var store
    @State private var isPicking = false

    var body: some View {
        @Bindable var store = store
        Form {
            PaneHeader(pane: .timeZones, subtitle: "Clocks for other places, shown above the agenda in the popover.")
            Section {
                if store.settings.timeZones.isEmpty {
                    Text("No time zones yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach($store.settings.timeZones) { $zone in
                    TimeZoneRow(zone: $zone, index: index(of: zone), count: store.settings.timeZones.count, move: move, remove: remove)
                }
                .onMove { store.settings.timeZones.move(fromOffsets: $0, toOffset: $1) }
                Button("Add Time Zone…") { isPicking = true }
                    .buttonStyle(.glass)
            } header: {
                Text("Clocks")
            } footer: {
                Text("Drag to reorder. Leave a label empty to show the city.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Picker("Also show in the menu bar", selection: $store.settings.menuBarTimeZone) {
                    Text("None").tag(String?.none)
                    ForEach(store.settings.timeZones) { zone in
                        Text(zone.displayName).tag(Optional(zone.identifier))
                    }
                }
                .disabled(store.settings.timeZones.isEmpty)
            } header: {
                Text("Menu Bar")
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $isPicking) {
            TimeZonePicker(excluded: Set(store.settings.timeZones.map(\.identifier))) { identifier in
                store.settings.timeZones.append(WorldClockZone(identifier: identifier))
            }
        }
    }

    private func index(of zone: WorldClockZone) -> Int {
        store.settings.timeZones.firstIndex(of: zone) ?? 0
    }

    private func move(_ index: Int, by offset: Int) {
        let target = index + offset
        guard store.settings.timeZones.indices.contains(index), store.settings.timeZones.indices.contains(target) else { return }
        store.settings.timeZones.swapAt(index, target)
    }

    private func remove(_ identifier: String) {
        store.settings.removeTimeZone(identifier)
    }
}

/// One clock: a sun or moon, the city and its zone, the label field, the time there, and
/// a menu to move or remove it.
private struct TimeZoneRow: View {
    @Binding var zone: WorldClockZone
    let index: Int
    let count: Int
    let move: (Int, Int) -> Void
    let remove: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Redrawn every minute, so the time stays current while the window is open.
        TimelineView(.everyMinute) { context in
            let reading = WorldClock.reading(for: zone, now: context.date)
            HStack(spacing: 10) {
                Image(systemName: reading.isDaytime ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.legible(reading.isDaytime ? Theme.daytime : Theme.nighttime, colorScheme))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(WorldClock.cityName(for: zone.identifier))
                    Text(TimeZonePicker.offset(zone.identifier, now: context.date))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)
                Spacer(minLength: 8)
                TextField("Label", text: $zone.label, prompt: Text("Label"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 96)
                HStack(spacing: 4) {
                    Text(reading.time)
                        .monospacedDigit()
                    if let offset = reading.dayOffsetText {
                        Text(offset)
                            .font(.system(size: 10, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 70, alignment: .trailing)
                Menu {
                    Button("Move Up") { move(index, -1) }
                        .disabled(index == 0)
                    Button("Move Down") { move(index, 1) }
                        .disabled(index == count - 1)
                    Divider()
                    Button("Remove", role: .destructive) { remove(zone.identifier) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .buttonStyle(.borderless)
                .fixedSize()
                .help("More")
            }
        }
    }
}

/// The sheet for adding a clock: a search field over every time zone, by city.
struct TimeZonePicker: View {
    let excluded: Set<String>
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selection: String?

    var body: some View {
        let results = WorldClock.search(query).filter { !excluded.contains($0) }
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search cities or time zones", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .glassEffect(.regular, in: .capsule)
            .padding(12)
            List(results, id: \.self, selection: $selection) { identifier in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(WorldClock.cityName(for: identifier))
                        Text(identifier.replacingOccurrences(of: "_", with: " "))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Self.offset(identifier, now: .now))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .tag(identifier)
                .contentShape(.rect)
                .onTapGesture(count: 2) { pick(identifier) }
            }
            .listStyle(.inset)
            .overlay {
                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { selection.map(pick) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.glassProminent)
                    .disabled(selection == nil)
            }
            .buttonBorderShape(.capsule)
            .padding(12)
        }
        .frame(width: 420, height: 440)
    }

    private func pick(_ identifier: String) {
        onPick(identifier)
        dismiss()
    }

    /// "GMT-4", as of `now`.
    static func offset(_ identifier: String, now: Date) -> String {
        guard let zone = TimeZone(identifier: identifier) else { return identifier }
        return now.formatted(Date.FormatStyle(timeZone: zone).timeZone(.localizedGMT(.short)))
    }
}
