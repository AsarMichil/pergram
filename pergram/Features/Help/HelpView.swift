import SwiftUI

struct HelpView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Help coming soon",
                systemImage: "questionmark.circle",
                description: Text("How it works, and a way to send feedback.")
            )
            .navigationTitle("Help")
        }
    }
}

#Preview {
    HelpView()
}
