import Foundation

/// Maps Lexicon types to Swift types.
struct TypeMapper {

    private let naming = NamingStrategy()

    // MARK: - String Format Mapping

    /// Map a Lexicon `string` format to the corresponding Swift type name.
    func mapStringFormat(_ format: String?) -> String {
        guard let format = format else { return "String" }
        switch format {
        case "datetime":  return "Date"
        case "uri":       return "URL"
        case "at-uri":    return "ATURI"
        case "did":       return "DID"
        case "handle":    return "Handle"
        case "nsid":      return "NSID"
        case "tid":       return "TID"
        case "cid":       return "String"
        case "language":  return "String"
        default:          return "String"
        }
    }

    // MARK: - Property Type Mapping

    /// Map a ``PropertyDef`` to the Swift type string.
    ///
    /// - Parameters:
    ///   - prop: The property definition from the Lexicon schema.
    ///   - required: Whether the property is required (non-optional).
    ///   - currentNSID: The NSID of the document being processed (used to resolve local refs).
    /// - Returns: A Swift type string such as `"String"`, `"Int?"`, `"[URL]"`, etc.
    func mapPropertyType(_ prop: PropertyDef, required: Bool, currentNSID: String) -> String {
        let baseType: String
        switch prop {
        case .string(let def):
            if let enumValues = def.enum, !enumValues.isEmpty {
                // Enum values are handled separately; the generated enum
                // name will be assigned by the caller.
                baseType = "String"
            } else {
                baseType = mapStringFormat(def.format)
            }
        case .integer:
            baseType = "Int"
        case .boolean:
            baseType = "Bool"
        case .array(let def):
            let itemType = mapPropertyType(def.items, required: true, currentNSID: currentNSID)
            baseType = "[\(itemType)]"
        case .ref(let def):
            baseType = mapRef(def.ref, currentNSID: currentNSID)
        case .union(let def):
            // Unions are generated as dedicated enum types by the caller;
            // for inline usage we produce the base name placeholder.
            if def.refs.count == 1 {
                baseType = mapRef(def.refs[0], currentNSID: currentNSID)
            } else {
                // The caller is expected to replace this with the actual
                // generated union enum name.
                baseType = "LexiconUnion"
            }
        case .blob:
            baseType = "BlobRef"
        case .bytes:
            baseType = "Data"
        case .cidLink:
            baseType = "CIDLink"
        case .unknown:
            baseType = "LexiconValue"
        }

        if required {
            return baseType
        }
        return "\(baseType)?"
    }

    // MARK: - Reference Resolution

    /// Resolve a Lexicon `$ref` string to a Swift type name.
    ///
    /// - Parameters:
    ///   - ref: The reference string (e.g. `"#replyRef"` or `"com.atproto.repo.strongRef"`).
    ///   - currentNSID: The NSID of the current document.
    /// - Returns: A Swift type name.
    func mapRef(_ ref: String, currentNSID: String) -> String {
        if ref.hasPrefix("#") {
            // Local reference within the same document.
            let defName = String(ref.dropFirst())
            return naming.structName(for: currentNSID, defName: defName)
        }
        // External reference — may include a fragment.
        let parts = ref.split(separator: "#", maxSplits: 1)
        let nsid = String(parts[0])
        if parts.count > 1 {
            let defName = String(parts[1])
            return naming.structName(for: nsid, defName: defName)
        }
        return swiftTypeName(for: nsid)
    }

    /// Convert an NSID to a PascalCase Swift type name.
    func swiftTypeName(for nsid: String) -> String {
        naming.pascalCase(fromNSID: nsid)
    }
}
