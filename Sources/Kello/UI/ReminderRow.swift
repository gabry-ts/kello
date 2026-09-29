import KelloCore
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
                    Hairline(leading: 38)
                }
                ReminderRow(reminder: reminder, now: now, onComplete: { onComplete(reminder) }) { onOpen(reminder) }
            }
        }
        .clipShape(.rect(cornerRadius: Theme.groupRadius, style: .continuous))
        .surface(radius: Theme.groupRadius)
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
    @State private var isChecked = false

    var body: some View {
        let isOverdue = reminder.isOverdue(now: now)
        let color = Color(reminder.color)
        HStack(alignment: .top, spacing: 10) {
            Button(action: check) {
                Checkbox(isChecked: isChecked, color: color)
            }
            .buttonStyle(.plain)
            .help("Complete")
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if reminder.priority != 0 {
                        Text(String(repeating: "!", count: priorityMarks))
                            .fontWeight(.bold)
                            .foregroundStyle(color)
                    }
                    Text(reminder.title)
                        .strikethrough(isChecked)
                        .lineLimit(2)
                }
                .font(.system(size: 13))
                if let due = reminder.due {
                    Text(dueText(due))
                        .font(.system(size: 11.5))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if isOverdue, let due = reminder.due {
                Text(AgendaFormat.overdueAge(since: due, now: now))
                    .font(.system(size: 11.5))
                    .monospacedDigit()
                    .foregroundStyle(Theme.destructive)
                    .padding(.top, 1)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .opacity(isChecked ? 0.5 : 1)
        .contentShape(.rect)
        .hoverHighlight(cornerRadius: 0, opacity: 0.04)
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
        withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(duration: 0.3, bounce: 0.4)) { isChecked = true }
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
                .font(.system(size: 8.5, weight: .heavy))
                .foregroundStyle(.white)
                .scaleEffect(isChecked ? 1 : 0.4)
                .opacity(isChecked ? 1 : 0)
        }
        .frame(width: 16, height: 16)
        .padding(.top, 0.5)
        // A larger target than the ring itself.
        .padding(4)
        .contentShape(.circle)
        .padding(-4)
        .onHover { isHovered = $0 }
        .animation(Theme.hover, value: isHovered)
    }
}
