import KelloCore
import SwiftUI

/// One event in the agenda: a rounded card washed with the calendar color, a colored
/// capsule on its leading edge, the title with the time on the right, then the location
/// and the call or link host, with a recurrence icon. Past events are dimmed.
struct EventRow: View {
    let event: CalendarEvent
    let now: Date
    var onOpen: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isPast = event.isPast(now: now)
        let isStruck = event.isDeclined || event.isCancelled
        let isDimmed = isPast || isStruck
        let color = Color(event.color)
        let dark = colorScheme == .dark
        let shape = RoundedRectangle(cornerRadius: Theme.rowRadius, style: .continuous)
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(event.title)
                    .font(.system(size: 13, weight: .semibold))
                    .strikethrough(isStruck)
                    .lineLimit(2)
                Spacer(minLength: 6)
                Text(AgendaFormat.timeRange(start: event.start, end: event.end, isAllDay: event.isAllDay, showsTimeZone: false))
                    .font(.system(size: 11.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            if let subtitle = event.displayedSubtitle {
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            details
        }
        .padding(.leading, 12)
        .opacity(isDimmed ? 0.5 : 1)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(color)
                .frame(width: 4)
                .opacity(isDimmed ? 0.55 : 1)
        }
        .padding(.vertical, 9)
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            shape.fill(color.opacity(isDimmed ? (dark ? 0.06 : 0.05) : (dark ? 0.16 : 0.10)))
            shape.strokeBorder(color.opacity(isDimmed ? 0.10 : 0.22), lineWidth: 0.5)
        }
        .contentShape(shape)
        .hoverHighlight()
        .onTapGesture { onOpen?() }
    }

    /// The call or link host, then the recurrence icon on the right, or "Repeats" alone.
    @ViewBuilder
    private var details: some View {
        let link = event.meetingURL ?? event.url
        if let link {
            HStack(spacing: 5) {
                Image(systemName: event.meetingURL != nil ? "video.fill" : "link")
                    .font(.system(size: 9.5))
                Text(link.displayHost)
                    .lineLimit(1)
                if event.isRecurring {
                    Spacer(minLength: 0)
                    RecurrenceIcon()
                }
            }
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
        } else if event.isRecurring {
            HStack(spacing: 4) {
                RecurrenceIcon()
                Text("Repeats")
            }
            .font(.system(size: 11.5))
            .foregroundStyle(.tertiary)
        }
    }
}

struct RecurrenceIcon: View {
    var body: some View {
        Image(systemName: "repeat")
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(.tertiary)
            .help("Repeats")
    }
}

/// The marker between today's past and upcoming events: a glowing dot, a line fading out,
/// and the time left until the next one.
struct NowMarker: View {
    let untilNext: TimeInterval?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Theme.destructive)
                .frame(width: 7, height: 7)
                .shadow(color: Theme.destructive.opacity(0.6), radius: 3)
            Capsule()
                .fill(LinearGradient(colors: [Theme.destructive.opacity(0.8), Theme.destructive.opacity(0.12)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 1.5)
            if let untilNext {
                Text("in \(AgendaFormat.compactDuration(untilNext))")
                    .font(.system(size: 10.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.destructive)
                    .padding(.horizontal, 7)
                    .frame(height: 18)
                    .background(Theme.destructive.opacity(0.12), in: .capsule)
            }
        }
        .padding(.leading, 2)
        .padding(.vertical, 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Now")
    }
}

/// The calendar or list color running down the leading edge of a row.
struct ColorBar: View {
    let color: Color

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: 4)
            .frame(maxHeight: .infinity)
    }
}

/// The next event today that hasn't started, at the top of the agenda: a card tinted with
/// its calendar color, a countdown, its time and location, and a Join button for calls.
struct NextUpCard: View {
    let event: CalendarEvent
    let now: Date
    var onOpen: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let color = Color(event.color)
        let ink = Theme.legible(color, colorScheme)
        let dark = colorScheme == .dark
        let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text("Next up")
                    .textCase(.uppercase)
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(ink)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .semibold))
                    Text("in \(AgendaFormat.compactDuration(event.start.timeIntervalSince(now)))")
                        .font(.system(size: 11.5, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(ink)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(color.opacity(dark ? 0.20 : 0.14), in: .capsule)
            }
            Text(event.title)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(2)
                .padding(.top, 8)
            HStack(spacing: 5) {
                Text(AgendaFormat.timeRange(start: event.start, end: event.end, isAllDay: false))
                    .monospacedDigit()
                    .layoutPriority(1)
                if let subtitle = event.displayedSubtitle {
                    Text("·").foregroundStyle(.tertiary)
                    Text(subtitle).lineLimit(1)
                }
                Spacer(minLength: 0)
                if event.isRecurring {
                    RecurrenceIcon()
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.top, 3)
            if let meetingURL = event.meetingURL {
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 10))
                        Text(meetingURL.displayHost)
                            .lineLimit(1)
                    }
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        NSWorkspace.shared.open(meetingURL)
                    } label: {
                        Label("Join", systemImage: "video.fill")
                            .font(.system(size: 12.5, weight: .semibold))
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .tint(Theme.join)
                }
                .padding(.top, 12)
            }
        }
        .padding(14)
        .background {
            shape.fill(RadialGradient(colors: [color.opacity(dark ? 0.26 : 0.18), color.opacity(0)],
                                      center: .topLeading, startRadius: 0, endRadius: 260))
        }
        .surface(radius: Theme.cardRadius, tint: color, tintAmount: 1.2)
        .contentShape(shape)
        .hoverHighlight(cornerRadius: Theme.cardRadius, opacity: 0.03)
        .onTapGesture { onOpen?() }
    }
}

extension CalendarEvent {
    /// The location or first line of the notes, unless it's just the call link, which is
    /// shown as its host instead.
    var displayedSubtitle: String? {
        guard let subtitle else { return nil }
        if let link = meetingURL ?? url, subtitle == link.absoluteString { return nil }
        return subtitle
    }
}

extension URL {
    /// "meet.google.com" for a call or link, without the scheme, "www." or path.
    var displayHost: String {
        guard let host = host() else { return absoluteString }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
