import KelloCore
import PartitiUI
import SwiftUI

/// Time Zones settings: the extra clocks, each with an optional label, reordered by
/// dragging or from its menu, and which one's time also shows in the menu bar.
struct TimeZonesSettingsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.puiAccent) private var accent
    @State private var isPicking = false
    @State private var dropTarget: String?

    var body: some View {
        @Bindable var store = store
        KelloPane(pane: .timeZones, subtitle: String(localized: "Clocks for other places, shown above the agenda in the popover.")) {
            SettingsGroup(String(localized: "Clocks"), footer: String(localized: "Drag to reorder. Leave a label empty to show the city.")) {
                if store.settings.timeZones.isEmpty {
                    Text("No time zones yet.")
                        .font(PUI.Font.body)
                        .foregroundStyle(Ink(colorScheme).secondary)
                        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                        .padding(.horizontal, PUI.Space.l)
                }
                ForEach($store.settings.timeZones) { $zone in
                    TimeZoneRow(zone: $zone, isFirst: zone == store.settings.timeZones.first, isLast: zone == store.settings.timeZones.last,
                                move: move, remove: remove)
                        .background {
                            // The row the dragged clock will take the place of.
                            RoundedRectangle(cornerRadius: PUI.Radius.row, style: .continuous)
                                .fill(accent.color.opacity(dropTarget == zone.identifier ? 0.15 : 0))
                                .padding(PUI.Space.xxs)
                        }
                        .draggable(zone.identifier) {
                            Text(WorldClock.cityName(for: zone.identifier)).padding(PUI.Space.s)
                        }
                        .dropDestination(for: String.self) { values, _ in
                            guard let moved = values.first else { return false }
                            drop(moved, onto: zone.identifier)
                            return true
                        } isTargeted: { targeted in
                            if targeted { dropTarget = zone.identifier } else if dropTarget == zone.identifier { dropTarget = nil }
                        }
                }
                HStack {
                    Spacer()
                    Button("Add Time Zone…") { isPicking = true }
                        .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
                }
                .padding(.horizontal, PUI.Space.l)
                .padding(.vertical, PUI.Space.m)
            }
            SettingsGroup(String(localized: "Menu Bar")) {
                SettingsRow(String(localized: "Also show in the menu bar")) {
                    PopUpMenu(selection: $store.settings.menuBarTimeZone,
                              options: [(String?.none, Text("None"))]
                                  + store.settings.timeZones.map { (Optional($0.identifier), Text(verbatim: $0.displayName)) })
                        .accessibilityLabel(Text("Also show in the menu bar"))
                }
                .disabled(store.settings.timeZones.isEmpty)
            }
        }
        .sheet(isPresented: $isPicking) {
            TimeZonePicker(excluded: Set(store.settings.timeZones.map(\.identifier))) { identifier in
                store.settings.timeZones.append(WorldClockZone(identifier: identifier))
            }
        }
    }

    /// Moves a clock one place up or down, from its menu.
    private func move(_ identifier: String, by offset: Int) {
        store.settings.timeZones = Reorder.moving(store.settings.timeZones, id: identifier, by: offset)
    }

    /// Moves the dragged clock into `target`'s slot.
    private func drop(_ identifier: String, onto target: String) {
        store.settings.timeZones = Reorder.moving(store.settings.timeZones, id: identifier, onto: target)
    }

    private func remove(_ identifier: String) {
        store.settings.removeTimeZone(identifier)
    }
}

/// One clock: a sun or moon, the city and its zone, the label field, the time there, and
/// a menu to move or remove it.
private struct TimeZoneRow: View {
    @Binding var zone: WorldClockZone
    let isFirst: Bool
    let isLast: Bool
    let move: (String, Int) -> Void
    let remove: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Redrawn every minute, so the time stays current while the window is open.
        TimelineView(.everyMinute) { context in
            let ink = Ink(colorScheme)
            let reading = WorldClock.reading(for: zone, now: context.date)
            HStack(spacing: PUI.Space.m + 2) {
                Image(systemName: reading.isDaytime ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(reading.isDaytime ? KelloStyle.daytime(colorScheme) : KelloStyle.nighttime(colorScheme))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(WorldClock.cityName(for: zone.identifier))
                        .font(PUI.Font.body)
                        .foregroundStyle(ink.primary)
                    Text(TimeZonePicker.offset(zone.identifier, now: context.date))
                        .font(PUI.Font.caption)
                        .foregroundStyle(ink.secondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)
                Spacer(minLength: PUI.Space.m)
                TextField("Label", text: $zone.label, prompt: Text("Label"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 96)
                HStack(spacing: PUI.Space.xs) {
                    Text(reading.time)
                        .font(PUI.Font.body)
                        .monospacedDigit()
                        .foregroundStyle(ink.primary)
                    if let offset = reading.dayOffsetText {
                        Text(offset)
                            .font(PUI.Font.badge)
                            .monospacedDigit()
                            .foregroundStyle(ink.secondary)
                    }
                }
                .frame(minWidth: 70, alignment: .trailing)
                Menu {
                    Button("Move Up") { move(zone.identifier, -1) }
                        .disabled(isFirst)
                    Button("Move Down") { move(zone.identifier, 1) }
                        .disabled(isLast)
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
            .padding(.horizontal, PUI.Space.l)
            .padding(.vertical, PUI.Space.m)
            .frame(minHeight: 38)
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
            .padding(.horizontal, PUI.Space.l)
            .frame(height: 32)
            .puiGlass(Capsule())
            .padding(PUI.Space.l)
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
                    .buttonStyle(SecondaryButtonStyle())
                Button("Add") { selection.map(pick) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(PrimaryButtonStyle(height: PUI.Control.regular, fullWidth: false))
                    .disabled(selection == nil)
            }
            .padding(PUI.Space.l)
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
