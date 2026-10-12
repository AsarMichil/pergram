import CoreTransferable
import UniformTypeIdentifiers

extension UTType {
    static let pergramList = UTType(exportedAs: "com.asarmichil.pergram.list")
}

/// The file transport for a `ListPayload`. AirDrop, Messages and Files carry the file; anything that
/// cannot open it falls back to the plain-text checklist.
struct SharedListFile: Transferable {
    let payload: ListPayload

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .pergramList) { file in
            try file.payload.encoded()
        } importing: { data in
            SharedListFile(payload: try ListPayload.decode(from: data))
        }
        .suggestedFileName { "\($0.payload.name).pergram" }
        ProxyRepresentation(exporting: \.payload.plainText)
    }
}
