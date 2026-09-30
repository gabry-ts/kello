import KelloCore
import PartitiUI
import SwiftUI

/// One event in the agenda: a rounded row washed with the calendar color, a colored
/// capsule on its leading edge, the title with the time on the right, then the location
/// and the call service or link host, with a recurrence icon. Rows with a call show a
/// Join button while hovered. Past events are dimmed.
struct EventRow: View {
    let event: CalendarEvent
    let now: Date
    var onOpen: (() -> Void)?
    /// Draws the row as if hovered, for snapshots.
    var showsHoverState = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        let ink = Ink(colorScheme)
        let isPast = event.isPast(now: now)
        let isStruck = event.isDeclined || event.isCancelled
        let isDimmed = isPast || isStruck
        let color = Color(event.color)
        let shape = RoundedRectangle(cornerRadius: PUI.Radius.row, style: .continuous)
        HStack(spacing: PUI.Space.m) {
            Capsule()
                .fill(color)
                .frame(width: 3)
                .padding(.vertical, 1)
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: PUI.Space.s) {
                    Text(event.title)
                        .font(PUI.Font.headline)
                        .foregroundStyle(ink.primary)
                        .strikethrough(isStruck)
                        .lineLimit(2)
                    Spacer(minLength: PUI.Space.xs)
                    Text(AgendaFormat.timeText(start: event.start, end: event.end, isAllDay: event.isAllDay, showsTimeZone: false))
                        .font(PUI.Font.caption)
                        .monospacedDigit()
                        .foregroundStyle(ink.secondary)
                        .fixedSize()
                }
                if let subtitle = event.displayedSubtitle {
                    Text(subtitle)
                        .font(PUI.Font.caption)
                        .foregroundStyle(ink.secondary)
                        .lineLimit(2)
                }
                details(ink)
            }
        }
        .padding(.leading, PUI.Space.s)
        .padding(.trailing, PUI.Space.m)
        .padding(.vertical, PUI.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isDimmed ? 0.5 : 1)
        .puiHoverHighlight(isHovered)
        .background(shape.fill(color.opacity(colorScheme == .dark ? 0.12 : 0.08)))
        .contentShape(shape)
        .onHover { isHovered = $0 }
        .animation(PUI.Motion.hover, value: isHovered)
        .onTapGesture { onOpen?() }
    }

    /// The call service or link host, then the recurrence icon on the right, or "Repeats"
    /// alone. While hovered, a call's Join button takes the recurrence icon's place.
    @ViewBuilder
    private func details(_ ink: Ink) -> some View {
        let link = event.meetingURL ?? event.url
        let showsJoin = event.meetingURL != nil && (isHovered || showsHoverState)
        if let link {
            HStack(spacing: 3) {
                Image(systemName: event.meetingURL != nil ? "video.fill" : "link")
                    .font(.system(size: 8))
                Text(event.linkLabel ?? link.displayHost)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if event.isRecurring {
                    RecurrenceIcon()
                        .opacity(showsJoin ? 0 : 1)
                }
            }
            .font(PUI.Font.caption)
            .foregroundStyle(ink.secondary)
            // An overlay, so showing the button doesn't change the row's height.
            .overlay(alignment: .trailing) {
                if showsJoin, let meetingURL = event.meetingURL {
                    CallJoinButton(url: meetingURL, isCompact: true)
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
                }
            }
        } else if event.isRecurring {
            HStack(spacing: PUI.Space.xs) {
                RecurrenceIcon()
                Text("Repeats")
            }
            .font(PUI.Font.caption)
            .foregroundStyle(ink.tertiary)
        }
    }
}

struct RecurrenceIcon: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(systemName: "repeat")
            .font(.system(size: 8.5, weight: .semibold))
            .foregroundStyle(Ink(colorScheme).tertiary)
            .help("Repeats")
    }
}

/// The marker between today's past and upcoming events: a glowing dot, a line fading out,
/// and the time left until the next one.
struct NowMarker: View {
    let untilNext: TimeInterval?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let red = Ink(colorScheme).red
        HStack(spacing: PUI.Space.s) {
            Circle()
                .fill(red)
                .frame(width: 6, height: 6)
                .shadow(color: red.opacity(0.6), radius: 3)
            LinearGradient(colors: [red, red.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
            if let untilNext {
                Text("in \(AgendaFormat.compactDuration(untilNext))")
                    .font(PUI.Font.badge)
                    .monospacedDigit()
                    .foregroundStyle(red)
            }
        }
        .padding(.horizontal, PUI.Space.xs)
        .frame(height: 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Now")
    }
}

/// The next event today that hasn't started, at the top of the agenda: a card tinted with
/// its calendar color, a countdown, its time and location, and a Join button for calls.
struct NextUpCard: View {
    let event: CalendarEvent
    let now: Date
    var onOpen: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        let ink = Ink(colorScheme)
        let color = Color(event.color)
        let shape = RoundedRectangle(cornerRadius: PUI.Radius.card, style: .continuous)
        VStack(alignment: .leading, spacing: PUI.Space.xs) {
            HStack(spacing: PUI.Space.s) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text("Next up")
                    .textCase(.uppercase)
                    .font(PUI.Font.badge)
                    .tracking(PUI.Font.badgeTracking)
                    .foregroundStyle(PUI.legible(color, colorScheme))
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .semibold))
                    Text("in \(AgendaFormat.compactDuration(event.start.timeIntervalSince(now)))")
                        .font(PUI.Font.badge)
                        .monospacedDigit()
                }
                .foregroundStyle(ink.secondary)
                .padding(.horizontal, PUI.Space.s)
                .frame(height: 16)
                .background(Capsule().fill(ink.fill))
            }
            Text(event.title)
                .font(PUI.Font.headline)
                .foregroundStyle(ink.primary)
                .lineLimit(2)
                .padding(.top, PUI.Space.xxs)
            HStack(spacing: PUI.Space.xs) {
                Text(AgendaFormat.timeText(start: event.start, end: event.end, isAllDay: false))
                    .monospacedDigit()
                    .layoutPriority(1)
                if let subtitle = event.displayedSubtitle {
                    Text("·").foregroundStyle(ink.tertiary)
                    Text(subtitle).lineLimit(1)
                }
                Spacer(minLength: 0)
                if event.isRecurring {
                    RecurrenceIcon()
                }
            }
            .font(PUI.Font.caption)
            .foregroundStyle(ink.secondary)
            if let meetingURL = event.meetingURL {
                HStack(spacing: PUI.Space.xs) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 9))
                    Text(event.linkLabel ?? meetingURL.displayHost)
                        .font(PUI.Font.caption)
                        .lineLimit(1)
                    Spacer()
                    CallJoinButton(url: meetingURL)
                }
                .foregroundStyle(ink.secondary)
                .padding(.top, PUI.Space.xs)
            }
        }
        .padding(PUI.Space.m + 2)
        .background(shape.fill(isHovered ? ink.fill : .clear))
        .puiSurface(tint: color)
        .contentShape(shape)
        .onHover { isHovered = $0 }
        .animation(PUI.Motion.hover, value: isHovered)
        .onTapGesture { onOpen?() }
    }
}

/// Partiti UI's Join capsule, opening a call. Compact in event rows, where it sits over
/// the details line.
struct CallJoinButton: View {
    let url: URL
    var isCompact = false

    var body: some View {
        JoinButton(size: isCompact ? .compact : .regular) { NSWorkspace.shared.open(url) }
            .help("Join \(url.displayHost)")
    }
}

extension CalendarEvent {
    /// The location or first line of the notes, unless it's just the call link, which is
    /// shown as its service or host instead.
    var displayedSubtitle: String? {
        guard let subtitle else { return nil }
        if let link = meetingURL ?? url, subtitle == link.absoluteString { return nil }
        if meetingURL != nil, subtitle.contains("://"), MeetingLink.find(in: [subtitle]) == meetingURL { return nil }
        return subtitle
    }

    /// "Google Meet", "Zoom" or "Teams" for a call, nil for other links.
    var linkLabel: String? {
        meetingService?.name
    }
}

extension URL {
    /// "meet.google.com" for a call or link, without the scheme, "www." or path.
    var displayHost: String {
        guard let host = host() else { return absoluteString }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
