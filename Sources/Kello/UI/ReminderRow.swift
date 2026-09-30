import KelloCore
import PartitiUI
import SwiftUI

/// A run of reminders sharing one glass card, separated by hairlines.
struct ReminderGroup: View {
    let reminders: [ReminderItem]
    let now: Date
    let onComplete: (ReminderItem) -> Void
    let onOpen: (ReminderItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(reminders.enumerated()), id: \.element.id) { index, reminder in
                if index > 0 {
                    Hairline(leading: 31)
                }
                ReminderRow(reminder: reminder, now: now, onComplete: { onComplete(reminder) }) { onOpen(reminder) }
            }
        }
        .clipShape(.rect(cornerRadius: PUI.Radius.group, style: .continuous))
        .puiSurface(radius: PUI.Radius.group)
    }
}

/// One reminder: a circle that completes it, the title (after its priority) and due time,
/// and how long ago it was due when overdue.
struct ReminderRow: View {
    let reminder: ReminderItem
    let now: Date
    let onComplete: () -> Void
    var onOpen: (() -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var isChecked = false
    @State private var isHovered = false

    var body: some View {
        let ink = Ink(colorScheme)
        let isOverdue = reminder.isOverdue(now: now)
        let color = Color(reminder.color)
        HStack(alignment: .top, spacing: PUI.Space.m) {
            Button(action: check) {
                Checkbox(isChecked: isChecked, color: color)
            }
            .buttonStyle(.plain)
            .help("Complete")
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    if reminder.priority != 0 {
                        Text(String(repeating: "!", count: priorityMarks))
                            .fontWeight(.bold)
                            .foregroundStyle(color)
                    }
                    Text(reminder.title)
                        .foregroundStyle(ink.primary)
                        .strikethrough(isChecked)
                        .lineLimit(2)
                }
                .font(PUI.Font.body)
                // The overdue age shares the due line, leaving the title the full width.
                if let due = reminder.due {
                    HStack(alignment: .firstTextBaseline, spacing: PUI.Space.s) {
                        Text(dueText(due))
                            .foregroundStyle(ink.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if isOverdue {
                            Text(AgendaFormat.overdueAge(since: due, now: now))
                                .foregroundStyle(ink.red)
                                .fixedSize()
                        }
                    }
                    .font(PUI.Font.caption)
                    .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, PUI.Space.s)
        .padding(.horizontal, PUI.Space.m + 1)
        .opacity(isChecked ? 0.5 : 1)
        .puiHoverHighlight(isHovered, radius: 0)
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .animation(PUI.Motion.hover, value: isHovered)
        .onTapGesture { onOpen?() }
    }

    private var priorityMarks: Int {
        switch ReminderPriority(eventKitValue: reminder.priority) {
        case .high: 3
        case .medium: 2
        case .low: 1
        case .none: 0
        }
    }

    /// The time for timed reminders due today, otherwise the date too.
    private func dueText(_ due: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(due, inSameDayAs: now) {
            return reminder.hasDueTime ? due.formatted(date: .omitted, time: .shortened) : String(localized: "Today")
        }
        return reminder.hasDueTime ? due.formatted(date: .abbreviated, time: .shortened) : due.formatted(date: .abbreviated, time: .omitted)
    }

    /// Shows the checkmark for a moment, then completes the reminder, which removes it.
    private func check() {
        guard !isChecked else { return }
        withAnimation(reduceMotion ? PUI.Motion.spring(reduceMotion: true) : .spring(duration: 0.3, bounce: 0.4)) { isChecked = true }
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.smooth) { onComplete() }
        }
    }
}

/// The round checkbox: a ring in the list color, filling with a checkmark when done.
private struct Checkbox: View {
    let isChecked: Bool
    let color: Color
    @State private var isHovered = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(color, lineWidth: 1.5)
            Circle()
                .fill(color)
                .scaleEffect(isChecked ? 1 : (isHovered ? 0.45 : 0.001))
                .opacity(isChecked ? 1 : (isHovered ? 0.3 : 0))
            Image(systemName: "checkmark")
                .font(.system(size: 7.5, weight: .heavy))
                .foregroundStyle(.white)
                .scaleEffect(isChecked ? 1 : 0.4)
                .opacity(isChecked ? 1 : 0)
        }
        .frame(width: 14, height: 14)
        .padding(.top, 0.5)
        // A larger target than the ring itself.
        .padding(4)
        .contentShape(.circle)
        .padding(-4)
        .onHover { isHovered = $0 }
        .animation(PUI.Motion.hover, value: isHovered)
    }
}
