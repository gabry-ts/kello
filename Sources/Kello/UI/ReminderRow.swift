import KelloCore
import SwiftUI

/// One reminder: list color bar, a circle that completes it, the title and due time, and
/// how long ago it was due when overdue.
struct ReminderRow: View {
    let reminder: ReminderItem
    let now: Date
    let onComplete: () -> Void
    var onOpen: (() -> Void)?
    @State private var isChecked = false

    var body: some View {
        let isOverdue = reminder.isOverdue(now: now)
        HStack(alignment: .top, spacing: 8) {
            ColorBar(color: Color(reminder.color))
            Button(action: check) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isChecked ? AnyShapeStyle(Color(reminder.color)) : AnyShapeStyle(.secondary))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .help("Complete")
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if reminder.priority != 0 {
                        Text(String(repeating: "!", count: priorityMarks))
                            .foregroundStyle(Color(reminder.color))
                    }
                    Text(reminder.title)
                        .strikethrough(isChecked)
                        .lineLimit(2)
                }
                .font(.system(size: 13, weight: .medium))
                if let due = reminder.due {
                    Text(dueText(due))
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(isOverdue ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                }
            }
            Spacer(minLength: 4)
            if isOverdue, let due = reminder.due {
                Text(AgendaFormat.overdueAge(since: due, now: now))
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .opacity(isChecked ? 0.5 : 1)
        .contentShape(.rect)
        .hoverHighlight()
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
        withAnimation(.snappy) { isChecked = true }
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.smooth) { onComplete() }
        }
    }
}
