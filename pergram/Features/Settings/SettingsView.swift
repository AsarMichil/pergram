import MessageUI
import SwiftUI

struct SettingsView: View {
    @State private var isShowingMail = false

    private static let feedbackEmail = "help-pergram@asarmichil.com"
    private static let supportURL = URL(string: "https://asarmichil.com/pergram")!
    private static let privacyURL = URL(string: "https://asarmichil.com/pergram/privacy-policy")!
    private static let siteURL = URL(string: "https://asarmichil.com")!

    var body: some View {
        NavigationStack {
            List {
                Section("How it works") {
                    Text(
                        "Type or scan a shelf price. PerGram Go normalizes it to a price per 100g and "
                            + "compares it against the good prices you set."
                    )
                    Text("Good prices are your own, not live store data.")
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

                Section {
                    Link(destination: Self.privacyURL) {
                        Label("Privacy policy", systemImage: "hand.raised")
                    }
                    Link(destination: Self.supportURL) {
                        Label("Support", systemImage: "lifepreserver")
                    }
                } header: {
                    Text("Legal")
                } footer: {
                    // Open Government Licence – Canada asks for attribution of anything derived.
                    Text(
                        "Contains information licensed under the Open Government Licence – Canada.")
                }

                Section {
                    LabeledContent("Version", value: Self.appVersion)
                } footer: {
                    Link(destination: Self.siteURL) {
                        Text("Made by Asar · asarmichil.com")
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $isShowingMail) {
            MailComposeView(
                recipient: Self.feedbackEmail,
                subject: "PerGram Go feedback",
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
        return "\n\n—\nPerGram Go \(appVersion) · iOS \(os.majorVersion).\(os.minorVersion)"
    }
}

#Preview {
    SettingsView()
}
