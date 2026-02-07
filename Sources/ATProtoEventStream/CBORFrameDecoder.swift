import Foundation
import SwiftCBOR
import ATProtoCore

/// Decodes CBOR-framed messages from the AT Protocol event stream.
///
/// Each frame consists of two CBOR objects:
/// 1. Header: `{"op": 1, "t": "#commit"}` (op=1 for message, op=-1 for error)
/// 2. Body: The event payload
public struct CBORFrameDecoder: Sendable {

    public init() {}

    /// Frame header from the event stream
    public struct FrameHeader {
        public let op: Int  // 1 = message, -1 = error
        public let type: String?  // e.g. "#commit", "#identity", "#handle", "#account"
    }

    /// Decode a binary frame into a RepoEvent
    public func decode(_ data: Data) throws -> RepoEvent {
        // The frame contains concatenated CBOR items
        let bytes = [UInt8](data)

        // Decode header
        guard let headerCBOR = try? CBOR.decode(bytes) else {
            throw ATProtoError.frameDecodingError("Failed to decode frame header")
        }

        let header = try decodeHeader(headerCBOR)

        // Handle error frames
        if header.op == -1 {
            return .info(InfoEvent(name: "error", message: "Stream error"))
        }

        // Find where the second CBOR object starts
        // Re-encode header to determine its byte length
        let headerBytes = headerCBOR.encode()
        let bodyOffset = headerBytes.count

        guard bodyOffset < bytes.count else {
            throw ATProtoError.frameDecodingError("Frame has no body")
        }

        let bodyBytes = Array(bytes[bodyOffset...])
        guard let bodyCBOR = try? CBOR.decode(bodyBytes) else {
            throw ATProtoError.frameDecodingError("Failed to decode frame body")
        }

        // Dispatch based on type
        switch header.type {
        case "#commit":
            return try .commit(decodeCommit(bodyCBOR))
        case "#identity":
            return try .identity(decodeIdentity(bodyCBOR))
        case "#handle":
            return try .handle(decodeHandle(bodyCBOR))
        case "#account":
            return try .account(decodeAccount(bodyCBOR))
        case "#info":
            return try .info(decodeInfo(bodyCBOR))
        default:
            return .unknown(type: header.type ?? "unknown", data: data)
        }
    }

    // MARK: - Private decoders

    private func decodeHeader(_ cbor: CBOR) throws -> FrameHeader {
        guard case .map(let map) = cbor else {
            throw ATProtoError.frameDecodingError("Header is not a map")
        }

        var op: Int = 0
        var type: String?

        if case .negativeInt(let n) = map[.utf8String("op")] {
            op = -Int(n) - 1
        } else if case .unsignedInt(let n) = map[.utf8String("op")] {
            op = Int(n)
        }

        if case .utf8String(let t) = map[.utf8String("t")] {
            type = t
        }

        return FrameHeader(op: op, type: type)
    }

    private func decodeCommit(_ cbor: CBOR) throws -> CommitEvent {
        guard case .map(let map) = cbor else {
            throw ATProtoError.frameDecodingError("Commit body is not a map")
        }

        let seq = extractInt64(map[.utf8String("seq")]) ?? 0
        let tooBig = extractBool(map[.utf8String("tooBig")]) ?? false
        let repo = extractString(map[.utf8String("repo")]) ?? ""
        let rev = extractString(map[.utf8String("rev")])
        let time = extractString(map[.utf8String("time")]) ?? ""

        var ops: [RepoOp] = []
        if case .array(let opsArray) = map[.utf8String("ops")] {
            for opCBOR in opsArray {
                if case .map(let opMap) = opCBOR {
                    let action = extractString(opMap[.utf8String("action")]) ?? ""
                    let path = extractString(opMap[.utf8String("path")]) ?? ""
                    let opAction = RepoOp.Action(rawValue: action) ?? .create
                    ops.append(RepoOp(action: opAction, path: path, cid: nil))
                }
            }
        }

        var blocks: Data?
        if case .byteString(let b) = map[.utf8String("blocks")] {
            blocks = Data(b)
        }

        return CommitEvent(seq: seq, tooBig: tooBig, repo: repo, rev: rev, time: time, ops: ops, blocks: blocks)
    }

    private func decodeIdentity(_ cbor: CBOR) throws -> IdentityEvent {
        guard case .map(let map) = cbor else {
            throw ATProtoError.frameDecodingError("Identity body is not a map")
        }
        return IdentityEvent(
            seq: extractInt64(map[.utf8String("seq")]) ?? 0,
            did: extractString(map[.utf8String("did")]) ?? "",
            time: extractString(map[.utf8String("time")]) ?? "",
            handle: extractString(map[.utf8String("handle")])
        )
    }

    private func decodeHandle(_ cbor: CBOR) throws -> HandleEvent {
        guard case .map(let map) = cbor else {
            throw ATProtoError.frameDecodingError("Handle body is not a map")
        }
        return HandleEvent(
            seq: extractInt64(map[.utf8String("seq")]) ?? 0,
            did: extractString(map[.utf8String("did")]) ?? "",
            handle: extractString(map[.utf8String("handle")]) ?? "",
            time: extractString(map[.utf8String("time")]) ?? ""
        )
    }

    private func decodeAccount(_ cbor: CBOR) throws -> AccountEvent {
        guard case .map(let map) = cbor else {
            throw ATProtoError.frameDecodingError("Account body is not a map")
        }
        return AccountEvent(
            seq: extractInt64(map[.utf8String("seq")]) ?? 0,
            did: extractString(map[.utf8String("did")]) ?? "",
            time: extractString(map[.utf8String("time")]) ?? "",
            active: extractBool(map[.utf8String("active")]) ?? true,
            status: extractString(map[.utf8String("status")])
        )
    }

    private func decodeInfo(_ cbor: CBOR) throws -> InfoEvent {
        guard case .map(let map) = cbor else {
            throw ATProtoError.frameDecodingError("Info body is not a map")
        }
        return InfoEvent(
            name: extractString(map[.utf8String("name")]) ?? "",
            message: extractString(map[.utf8String("message")])
        )
    }

    // MARK: - CBOR extraction helpers

    private func extractString(_ cbor: CBOR?) -> String? {
        guard case .utf8String(let s) = cbor else { return nil }
        return s
    }

    private func extractInt64(_ cbor: CBOR?) -> Int64? {
        switch cbor {
        case .unsignedInt(let n): return Int64(n)
        case .negativeInt(let n): return -Int64(n) - 1
        default: return nil
        }
    }

    private func extractBool(_ cbor: CBOR?) -> Bool? {
        guard case .boolean(let b) = cbor else { return nil }
        return b
    }
}
