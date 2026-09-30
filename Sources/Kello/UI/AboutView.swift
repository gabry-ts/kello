import PartitiUI
import SwiftUI

/// About, laid out like Partiti UI's `AboutPane`: the icon, name, a line about Kello and
/// the version, then updates and a way to support it. Built from the same pieces rather
/// than the pane itself, so every line goes through Kello's own string catalog.
struct AboutView: View {
    @State private var automaticallyChecksForUpdates = Updater.automaticallyChecksForUpdates
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let ink = Ink(colorScheme)
        ScrollView {
            VStack(spacing: 0) {
                AppIconView()
                    .frame(width: 112, height: 112)
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)
                Text(verbatim: AppAccent.kello.name)
                    .font(PUI.Font.title)
                    .foregroundStyle(ink.primary)
                    .padding(.top, PUI.Space.l)
                Text("A calendar for your menu bar")
                    .font(PUI.Font.body)
                    .foregroundStyle(ink.secondary)
                    .padding(.top, PUI.Space.xxs)
                Text("Version \(AppVersion.string)")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(ink.tertiary)
                    .padding(.top, PUI.Space.s)
                    .textSelection(.enabled)

                SettingsGroup(String(localized: "Updates"),
                              footer: String(localized: "Kello asks once, the first time it can check, whether to check automatically from then on.")) {
                    SettingsRow(String(localized: "Automatically check for updates")) {
                        RowSwitch(String(localized: "Automatically check for updates"), isOn: $automaticallyChecksForUpdates)
                    }
                    SettingsRow(String(localized: "Check for updates now")) {
                        Button("Check for Updates…") { Updater.checkForUpdates() }
                            .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
                    }
                }
                .frame(maxWidth: 420)
                .padding(.top, PUI.Space.xxl)

                Text("Kello is free. If it makes your days a little easier, you can buy me a coffee.")
                    .font(PUI.Font.callout)
                    .foregroundStyle(ink.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, PUI.Space.xxl)
                CoffeeButton { ExternalLinks.openBuyMeACoffee() }
                    .padding(.top, PUI.Space.l)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 44)
            .padding(.horizontal, PUI.Space.xxl)
            .padding(.bottom, PUI.Space.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onChange(of: automaticallyChecksForUpdates) { _, enabled in
            Updater.automaticallyChecksForUpdates = enabled
        }
    }
}
