import KelloCore
import SwiftUI

/// One event in the agenda: calendar color bar, title, subtitle and time range, with
/// small icons for recurrence, links and video calls. Past events are dimmed.
struct EventRow: View {
    let event: CalendarEvent
    let now: Date
    var onOpen: (() -> Void)?

    var body: some View {
        let isPast = event.isPast(now: now)
        let isStruck = event.isDeclined || event.isCancelled
        HStack(alignment: .top, spacing: 8) {
            ColorBar(color: Color(event.color))
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .medium))
                        .strikethrough(isStruck)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    badges
                }
                if let subtitle = event.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(AgendaFormat.timeRange(start: event.start, end: event.end, isAllDay: event.isAllDay))
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .opacity(isPast || isStruck ? 0.5 : 1)
        .contentShape(.rect)
        .hoverHighlight()
        .onTapGesture { onOpen?() }
    }

    private var badges: some View {
        HStack(spacing: 4) {
            if event.meetingURL != nil {
                Image(systemName: "video")
            } else if event.url != nil {
                Image(systemName: "link")
            }
            if event.isRecurring {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
    }
}

/// The thin marker between today's past and upcoming events, with the time left until
/// the next one.
struct NowMarker: View {
    let untilNext: TimeInterval?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
            Rectangle()
                .fill(.red.opacity(0.7))
                .frame(height: 1)
            if let untilNext {
                Text(AgendaFormat.compactDuration(untilNext))
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}

/// The calendar or list color running down the leading edge of a row.
struct ColorBar: View {
    let color: Color

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: 3)
            .frame(maxHeight: .infinity)
    }
}

/// The next event today that hasn't started, at the top of the agenda: its time,
/// location, a countdown, and a Join button for video calls.
struct NextUpCard: View {
    let event: CalendarEvent
    let now: Date
    var onOpen: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ColorBar(color: Color(event.color))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text("Next up")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    Text("in \(AgendaFormat.compactDuration(event.start.timeIntervalSince(now)))")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.tint)
                }
                HStack(spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                    if event.isRecurring {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(AgendaFormat.timeRange(start: event.start, end: event.end, isAllDay: false))
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if let subtitle = event.subtitle, event.meetingURL?.absoluteString != subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let meetingURL = event.meetingURL {
                    Button {
                        NSWorkspace.shared.open(meetingURL)
                    } label: {
                        Label("Join", systemImage: "video.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.top, 2)
                }
            }
        }
        .padding(8)
        .background(.primary.opacity(0.05), in: .rect(cornerRadius: 10, style: .continuous))
        .contentShape(.rect)
        .onTapGesture { onOpen?() }
    }
}
