import SwiftUI

/// About: the icon, name, version and a line about Kello, then updates and a way to
/// support it.
struct AboutView: View {
    @State private var automaticallyChecksForUpdates = Updater.automaticallyChecksForUpdates

    var body: some View {
        Form {
            Section {
                VStack(spacing: 6) {
                    AppIconView()
                        .frame(width: 96, height: 96)
                        .accessibilityHidden(true)
                    Text(verbatim: "Kello")
                        .font(.system(size: 22, weight: .semibold))
                    Text("A calendar for your menu bar")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("Version \(AppVersion.string)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            Section {
                Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
                    .onChange(of: automaticallyChecksForUpdates) { _, enabled in
                        Updater.automaticallyChecksForUpdates = enabled
                    }
                Button("Check for Updates…") { Updater.checkForUpdates() }
            } header: {
                Text("Updates")
            } footer: {
                Text("Kello asks once, the first time it can check, whether to check automatically from then on.")
                    .foregroundStyle(.secondary)
            }
            Section {
                VStack(spacing: 10) {
                    Text("Kello is free. If it makes your days a little easier, you can buy me a coffee.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    CoffeeButton()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
        }
        .formStyle(.grouped)
    }
}

/// A capsule in Buy Me a Coffee's yellow with a glassy sheen. Painted rather than a tinted
/// glass button, which turns gray whenever the window isn't key.
private struct CoffeeButton: View {
    var body: some View {
        Button { ExternalLinks.openBuyMeACoffee() } label: {
            Label("Buy Me a Coffee", systemImage: "cup.and.saucer.fill")
        }
        .buttonStyle(CoffeeButtonStyle())
    }
}

private struct CoffeeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CoffeeButtonBody(configuration: configuration)
    }

    private struct CoffeeButtonBody: View {
        let configuration: Configuration
        @State private var isHovered = false
        @Environment(\.colorSchemeContrast) private var contrast

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 0.16, green: 0.10, blue: 0.04))
                .padding(.horizontal, 18)
                .frame(height: 34)
                .background {
                    ZStack {
                        Capsule().fill(Theme.coffee.gradient)
                        Capsule().fill(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0)], startPoint: .top, endPoint: .center))
                        Capsule().fill(.black.opacity(configuration.isPressed ? 0.12 : (isHovered ? 0.04 : 0)))
                        Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 1)
                        Capsule().strokeBorder(.black.opacity(contrast == .increased ? 0.4 : 0.12), lineWidth: 0.5)
                    }
                    .shadow(color: Theme.coffee.mix(with: .black, by: 0.4).opacity(0.35), radius: 6, y: 2)
                }
                .contentShape(.capsule)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .onHover { isHovered = $0 }
                .animation(Theme.hover, value: isHovered)
                .animation(Theme.hover, value: configuration.isPressed)
        }
    }
}
