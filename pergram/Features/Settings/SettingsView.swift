import MessageUI
import SwiftUI

struct SettingsView: View {
    @State private var isShowingMail = false

    private static let feedbackEmail = "helpPERGRAM@asarmichil.com"
    private static let privacyURL = URL(string: "https://asarmichil.github.io/pergram/privacy")!
    private static let supportURL = URL(string: "https://asarmichil.github.io/pergram/support")!

    var body: some View {
        NavigationStack {
            List {
                Section("How it works") {
                    Text(
                        "Type or scan a shelf price. PerGram normalizes it to a price per 100g and "
                            + "compares it against the good prices you set."
                    )
                    Text("Prices are your own baselines, not live store data.")
                        .foregroundStyle(.secondary)
                }

                Section("Feedback") {
                    if MFMailComposeViewController.canSendMail() {
                        Button {
                            isShowingMail = true
                        } label: {
                            Label("Send feedback", systemImage: "envelope")
                        }
                    } else {
                        ShareLink(item: Self.feedbackBody) {
                            Label("Send feedback", systemImage: "envelope")
                        }
                    }
                }

                Section("Legal") {
                    Link(destination: Self.privacyURL) {
                        Label("Privacy policy", systemImage: "hand.raised")
                    }
                    Link(destination: Self.supportURL) {
                        Label("Support", systemImage: "lifepreserver")
                    }
                }

                Section {
                    LabeledContent("Version", value: Self.appVersion)
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $isShowingMail) {
            MailComposeView(
                recipient: Self.feedbackEmail,
                subject: "PerGram feedback",
                body: Self.feedbackBody
            )
            .ignoresSafeArea()
        }
    }

    private static var appVersion: String {
        let short =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    private static var feedbackBody: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "\n\n—\nPerGram \(appVersion) · iOS \(os.majorVersion).\(os.minorVersion)"
    }
}

#Preview {
    SettingsView()
}
