import SwiftData
import SwiftUI
import UIKit

@main
struct PergramApp: App {
    let modelContainer: ModelContainer = {
        let schema = AppSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            AppTabView()
                .environment(router)
                .onOpenURL(perform: open)
        }
        .modelContainer(modelContainer)
    }

    private func open(_ url: URL) {
        let isScoped = url.startAccessingSecurityScopedResource()
        let result = Result { try ListPayload.decode(from: Data(contentsOf: url)) }
        if isScoped { url.stopAccessingSecurityScopedResource() }
        // Not opened in place, so iOS handed over a copy in Documents/Inbox that is ours to delete.
        if url.pathComponents.contains("Inbox") { try? FileManager.default.removeItem(at: url) }
        dismissPresentedSheets {
            router.incomingList = IncomingList(result: result)
        }
    }

    /// A sheet can only present from the top of the stack, so an import arriving over the item
    /// picker or a cart entry would otherwise be dropped without a word.
    private func dismissPresentedSheets(then present: @escaping () -> Void) {
        let root = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        guard let root, root.presentedViewController != nil else {
            present()
            return
        }
        root.dismiss(animated: true, completion: present)
    }
}
