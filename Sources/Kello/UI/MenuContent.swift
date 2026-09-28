import SwiftUI

/// The menu bar popover. Replaced with the month grid in a later step.
struct MenuContent: View {
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kello")
                .font(.headline)
            Text(Date.now, style: .date)
                .foregroundStyle(.secondary)
            Divider()
            HStack(spacing: 14) {
                Button(action: openSettings) {
                    Label("Settings…", systemImage: "gearshape")
                }
                .keyboardShortcut(",")
                Spacer()
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit Kello", systemImage: "power")
                }
                .keyboardShortcut("q")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .font(.callout)
        }
        .padding(12)
        .frame(width: 280)
    }
}
