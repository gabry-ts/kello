import PartitiUI
import SwiftUI

/// About, from Partiti UI's `AboutPane`. Kello's tagline, coffee line and version are
/// Kello's own strings; the Updates group and its labels come from Partiti UI's catalog.
struct AboutView: View {
    @State private var automaticallyChecksForUpdates = Updater.automaticallyChecksForUpdates

    var body: some View {
        ScrollView {
            AboutPane(
                brand: PartitiBrand(accent: .kello,
                                    tagline: String(localized: "A calendar for your menu bar"),
                                    coffeeLine: String(localized: "Kello is free. If it makes your days a little easier, you can buy me a coffee."),
                                    icon: AppIconView.image),
                version: String(localized: "Version \(AppVersion.string)"),
                checksAutomatically: $automaticallyChecksForUpdates,
                onCheckForUpdates: { Updater.checkForUpdates() },
                onBuyMeACoffee: { ExternalLinks.openBuyMeACoffee() })
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
