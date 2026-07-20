import SwiftUI

struct ScanView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Scan coming soon",
                systemImage: "camera.viewfinder",
                description: Text("Camera and OCR land in a later milestone.")
            )
            .navigationTitle("Scan")
        }
    }
}

#Preview {
    ScanView()
}
