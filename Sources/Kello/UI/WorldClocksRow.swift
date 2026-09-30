import KelloCore
import PartitiUI
import SwiftUI

/// The extra time zones above the agenda: one card split into a column per clock, each
/// with a sun or moon, its name, the time there and how many days it's ahead or behind.
/// Up to three share the width; more scroll sideways.
struct WorldClocksRow: View {
    let zones: [WorldClockZone]
    let now: Date
    @Environment(\.colorScheme) private var colorScheme

    private static let maxFitting = 3
    private static let scrollingWidth: CGFloat = 76

    var body: some View {
        let readings = zones.map { WorldClock.reading(for: $0, now: now) }
        Group {
            if readings.count <= Self.maxFitting {
                columns(readings, width: nil)
            } else {
                ScrollView(.horizontal) {
                    columns(readings, width: Self.scrollingWidth)
                }
                .scrollIndicators(.never)
            }
        }
        .padding(.vertical, PUI.Space.s)
        .puiSurface(radius: PUI.Radius.group, elevated: false)
    }

    private func columns(_ readings: [WorldClockReading], width: CGFloat?) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(readings.enumerated()), id: \.offset) { index, reading in
                if index > 0 {
                    Rectangle()
                        .fill(Ink(colorScheme).hairline)
                        .frame(width: 0.5, height: 22)
                }
                ClockColumn(reading: reading)
                    .frame(width: width)
                    .frame(maxWidth: width == nil ? .infinity : nil)
            }
        }
    }
}

private struct ClockColumn: View {
    let reading: WorldClockReading
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let ink = Ink(colorScheme)
        VStack(spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: reading.isDaytime ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 7.5, weight: .semibold))
                    .foregroundStyle(reading.isDaytime ? KelloStyle.daytime(colorScheme) : KelloStyle.nighttime(colorScheme))
                Text(reading.name)
                    .font(PUI.Font.caption.weight(.medium))
                    .foregroundStyle(ink.secondary)
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(reading.time)
                    .font(PUI.Font.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(ink.primary)
                    .lineLimit(1)
                if let offset = reading.dayOffsetText {
                    Text(offset)
                        .font(PUI.Font.badge)
                        .monospacedDigit()
                        .foregroundStyle(ink.secondary)
                }
            }
        }
        .padding(.horizontal, PUI.Space.xs)
        .accessibilityElement(children: .combine)
    }
}
