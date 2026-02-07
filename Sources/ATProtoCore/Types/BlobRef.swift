import Foundation

/// A reference to a blob (binary large object) stored on a PDS.
///
/// Blob references include a CID link, MIME type, and size.
/// In JSON: `{"$type": "blob", "ref": {"$link": "..."}, "mimeType": "...", "size": ...}`
public struct BlobRef: Sendable, Hashable, Codable {
    /// The CID of the blob content
    public let ref: CIDLink

    /// The MIME type of the blob
    public let mimeType: String

    /// The size of the blob in bytes
    public let size: Int

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
        case ref
        case mimeType
        case size
    }

    public init(ref: CIDLink, mimeType: String, size: Int) {
        self.ref = ref
        self.mimeType = mimeType
        self.size = size
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Verify type marker if present
        if let type = try container.decodeIfPresent(String.self, forKey: .type) {
            guard type == "blob" else {
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Expected $type 'blob', got '\(type)'"
                )
            }
        }

        self.ref = try container.decode(CIDLink.self, forKey: .ref)
        self.mimeType = try container.decode(String.self, forKey: .mimeType)
        self.size = try container.decode(Int.self, forKey: .size)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("blob", forKey: .type)
        try container.encode(ref, forKey: .ref)
        try container.encode(mimeType, forKey: .mimeType)
        try container.encode(size, forKey: .size)
    }
}
