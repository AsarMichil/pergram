import LinkPresentation
import UIKit

/// Sends a list as a `.pergram` file over AirDrop, where the other phone opens it in PerGram, and
/// as a readable checklist everywhere else, since Messages and Mail show a file they cannot open as
/// an unreadable attachment.
final class ListShareItem: NSObject, UIActivityItemSource {
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6799463251")!

    private let payload: ListPayload
    private let file: URL?

    init(payload: ListPayload) {
        self.payload = payload
        file = try? Self.writeFile(for: payload)
    }

    static func message(for payload: ListPayload) -> String {
        payload.plainText + "\n\nMade with PerGram Go — get it on the App Store: "
            + appStoreURL.absoluteString
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        Self.message(for: payload)
    }

    func activityViewController(
        _ controller: UIActivityViewController, itemForActivityType type: UIActivity.ActivityType?
    ) -> Any? {
        if type == .airDrop, let file { return file }
        return Self.message(for: payload)
    }

    func activityViewController(
        _ controller: UIActivityViewController,
        subjectForActivityType type: UIActivity.ActivityType?
    ) -> String {
        payload.name
    }

    func activityViewControllerLinkMetadata(
        _ controller: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = payload.name
        return metadata
    }

    private static func writeFile(for payload: ListPayload) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let pathSeparators = CharacterSet(charactersIn: "/:")
        let name = payload.name.components(separatedBy: pathSeparators).joined(separator: "-")
        let file = folder.appending(path: "\(name).pergram")
        try payload.encoded().write(to: file)
        return file
    }
}

enum ListShare {
    /// Presented from UIKit because SwiftUI's `ShareLink` sends the same items to every destination.
    static func present(_ payload: ListPayload) {
        let root = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        guard var top = root else { return }
        while let presented = top.presentedViewController { top = presented }
        let controller = UIActivityViewController(
            activityItems: [ListShareItem(payload: payload)], applicationActivities: nil)
        top.present(controller, animated: true)
    }
}
