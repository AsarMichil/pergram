import SwiftData
import SwiftUI

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
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        let result = Result { try ListPayload.decode(from: Data(contentsOf: url)) }
        router.incomingList = IncomingList(result: result)
    }
}
