import KelloCore
import SwiftUI

/// The scrolling list under the grid: sections with a centered relative header, then
/// their reminders, events and the "now" marker. Grows with its content up to
/// `maxHeight`, then scrolls.
struct AgendaView: View {
    let sections: [AgendaSection]
    let now: Date
    var maxHeight: CGFloat = 360
    var openEvent: (CalendarEvent) -> Void = { _ in }
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        if sections.isEmpty {
            Text("No Events")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(sections) { section in
                        SectionHeader(title: section.title)
                        ForEach(section.entries) { entry in
                            row(entry)
                        }
                    }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.automatic)
            .frame(height: min(max(contentHeight, 1), maxHeight))
        }
    }

    @ViewBuilder
    private func row(_ entry: AgendaEntry) -> some View {
        switch entry {
        case .event(let event):
            EventRow(event: event, now: now) { openEvent(event) }
        case .reminder:
            EmptyView()
        case .now(let untilNext):
            NowMarker(untilNext: untilNext)
        }
    }
}

/// "Today", centered between two hairlines.
struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            line
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .fixedSize()
            line
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    private var line: some View {
        Rectangle()
            .fill(.primary.opacity(0.12))
            .frame(height: 1)
    }
}
