import Foundation
import Observation

enum AppTab: Hashable {
    case check
    case lists
    case items
    case settings
}

/// Shared so one tab can send the shopper to another — *Shop this list* lands on Check's Shop page —
/// and so an opened `.pergram` file can raise the import sheet over whichever tab is showing.
@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .check
    var checkMode: CheckInputMode = .type
    var incomingList: IncomingList?

    func shop() {
        tab = .check
        checkMode = .shop
    }
}

struct IncomingList: Identifiable {
    let id = UUID()
    let result: Result<ListPayload, Error>
}
