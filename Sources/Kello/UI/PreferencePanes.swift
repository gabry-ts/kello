import SwiftUI

struct GeneralView: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: AppVersion.string)
            }
        }
        .formStyle(.grouped)
    }
}

/// The version and build shown in General, read from the app's own bundle.
enum AppVersion {
    static var string: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }
}
