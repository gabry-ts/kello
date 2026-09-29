import SwiftUI

/// The menu bar popover.
struct MenuContent: View {
    let openSettings: () -> Void
    @Environment(CalendarStore.self) private var calendars
    @State private var viewModel = MonthGridViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonthGridView(viewModel: viewModel)
            if calendars.needsPermissionPrompt {
                Divider()
                PermissionView()
            }
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
        .frame(width: 308)
        .onAppear { calendars.refreshAccess() }
    }
}
