import Foundation
import SwiftData

@MainActor
enum StoreUpkeep {
    /// Removes every item nothing needs any more. One sweep, run wherever items can be orphaned —
    /// launch, a list or entry deleted, an item sheet closed — rather than a check at each site.
    static func prune(in context: ModelContext) {
        let items = (try? context.fetch(FetchDescriptor<GroceryItem>())) ?? []
        let unused = items.filter(\.isUnused)
        guard !unused.isEmpty else { return }
        unused.forEach(context.delete)
        try? context.save()
    }
}
