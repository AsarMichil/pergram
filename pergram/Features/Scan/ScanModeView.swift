import SwiftUI

struct ScanModeView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Scan lands soon", systemImage: "camera.viewfinder")
        } description: {
            Text(
                "Point at a shelf tag and read the price straight off it. Coming in a later update."
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    ScanModeView()
}
