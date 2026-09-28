import SwiftUI

/// Placeholder popover content, replaced with the month grid and a settings entry point
/// in later steps.
struct MenuContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kello")
                .font(.headline)
            Text(Date.now, style: .date)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 280)
    }
}
