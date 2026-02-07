import Foundation

// MARK: - Top-level Document

/// Parsed representation of a Lexicon document.
struct LexiconDocument: Codable {
    let lexicon: Int      // Should be 1
    let id: String        // NSID e.g. "app.bsky.feed.post"
    let defs: [String: LexiconDef]
    let description: String?

    init(lexicon: Int, id: String, defs: [String: LexiconDef], description: String? = nil) {
        self.lexicon = lexicon
        self.id = id
        self.defs = defs
        self.description = description
    }
}

// MARK: - Definition Types

/// A top-level definition inside a Lexicon document.
enum LexiconDef: Codable {
    case record(RecordDef)
    case query(QueryDef)
    case procedure(ProcedureDef)
    case subscription(SubscriptionDef)
    case object(ObjectDef)
    case string(StringDef)
    case token(TokenDef)
    case array(ArrayDef)

    // MARK: Codable

    private enum TypeKey: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TypeKey.self)
        let type = try container.decode(String.self, forKey: .type)

        let singleValue = try decoder.singleValueContainer()
        switch type {
        case "record":
            self = .record(try singleValue.decode(RecordDef.self))
        case "query":
            self = .query(try singleValue.decode(QueryDef.self))
        case "procedure":
            self = .procedure(try singleValue.decode(ProcedureDef.self))
        case "subscription":
            self = .subscription(try singleValue.decode(SubscriptionDef.self))
        case "object":
            self = .object(try singleValue.decode(ObjectDef.self))
        case "string":
            self = .string(try singleValue.decode(StringDef.self))
        case "token":
            self = .token(try singleValue.decode(TokenDef.self))
        case "array":
            self = .array(try singleValue.decode(ArrayDef.self))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown lexicon def type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .record(let v):       try container.encode(v)
        case .query(let v):        try container.encode(v)
        case .procedure(let v):    try container.encode(v)
        case .subscription(let v): try container.encode(v)
        case .object(let v):       try container.encode(v)
        case .string(let v):       try container.encode(v)
        case .token(let v):        try container.encode(v)
        case .array(let v):        try container.encode(v)
        }
    }
}

// MARK: - Record

struct RecordDef: Codable {
    let type: String  // "record"
    let description: String?
    let key: String?
    let record: ObjectDef
}

// MARK: - Query

struct QueryDef: Codable {
    let type: String  // "query"
    let description: String?
    let parameters: ParametersDef?
    let output: OutputDef?
    let errors: [ErrorDef]?
}

// MARK: - Procedure

struct ProcedureDef: Codable {
    let type: String  // "procedure"
    let description: String?
    let input: InputDef?
    let output: OutputDef?
    let errors: [ErrorDef]?
}

// MARK: - Subscription

struct SubscriptionDef: Codable {
    let type: String  // "subscription"
    let description: String?
    let parameters: ParametersDef?
    let message: MessageDef?
}

// MARK: - Object

struct ObjectDef: Codable {
    let type: String  // "object"
    let description: String?
    let required: [String]?
    let nullable: [String]?
    let properties: [String: PropertyDef]?
}

// MARK: - Property (union)

/// A Lexicon property schema definition. This is an indirect enum because
/// ``ArrayPropertyDef`` contains a nested ``PropertyDef`` for its items.
indirect enum PropertyDef: Codable {
    case string(StringPropertyDef)
    case integer(IntegerPropertyDef)
    case boolean(BooleanPropertyDef)
    case array(ArrayPropertyDef)
    case ref(RefPropertyDef)
    case union(UnionPropertyDef)
    case blob(BlobPropertyDef)
    case bytes(BytesPropertyDef)
    case cidLink(CIDLinkPropertyDef)
    case unknown(UnknownPropertyDef)

    // MARK: Codable

    private enum TypeKey: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TypeKey.self)
        let type = try container.decode(String.self, forKey: .type)

        let singleValue = try decoder.singleValueContainer()
        switch type {
        case "string":
            self = .string(try singleValue.decode(StringPropertyDef.self))
        case "integer":
            self = .integer(try singleValue.decode(IntegerPropertyDef.self))
        case "boolean":
            self = .boolean(try singleValue.decode(BooleanPropertyDef.self))
        case "array":
            self = .array(try singleValue.decode(ArrayPropertyDef.self))
        case "ref":
            self = .ref(try singleValue.decode(RefPropertyDef.self))
        case "union":
            self = .union(try singleValue.decode(UnionPropertyDef.self))
        case "blob":
            self = .blob(try singleValue.decode(BlobPropertyDef.self))
        case "bytes":
            self = .bytes(try singleValue.decode(BytesPropertyDef.self))
        case "cid-link":
            self = .cidLink(try singleValue.decode(CIDLinkPropertyDef.self))
        case "unknown":
            self = .unknown(try singleValue.decode(UnknownPropertyDef.self))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown property type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v):   try container.encode(v)
        case .integer(let v):  try container.encode(v)
        case .boolean(let v):  try container.encode(v)
        case .array(let v):    try container.encode(v)
        case .ref(let v):      try container.encode(v)
        case .union(let v):    try container.encode(v)
        case .blob(let v):     try container.encode(v)
        case .bytes(let v):    try container.encode(v)
        case .cidLink(let v):  try container.encode(v)
        case .unknown(let v):  try container.encode(v)
        }
    }
}

// MARK: - Property Leaf Types

struct StringPropertyDef: Codable {
    let type: String
    let description: String?
    let format: String?
    let maxLength: Int?
    let minLength: Int?
    let maxGraphemes: Int?
    let minGraphemes: Int?
    let knownValues: [String]?
    let `enum`: [String]?
    let `default`: String?
    let const: String?
}

struct IntegerPropertyDef: Codable {
    let type: String
    let description: String?
    let minimum: Int?
    let maximum: Int?
    let `default`: Int?
    let const: Int?
}

struct BooleanPropertyDef: Codable {
    let type: String
    let description: String?
    let `default`: Bool?
    let const: Bool?
}

struct ArrayPropertyDef: Codable {
    let type: String
    let description: String?
    let items: PropertyDef
    let maxLength: Int?
    let minLength: Int?
}

struct RefPropertyDef: Codable {
    let type: String  // "ref"
    let description: String?
    let ref: String

    private enum CodingKeys: String, CodingKey {
        case type
        case description
        case ref = "$ref"
    }
}

struct UnionPropertyDef: Codable {
    let type: String  // "union"
    let description: String?
    let refs: [String]
    let closed: Bool?

    private enum CodingKeys: String, CodingKey {
        case type
        case description
        case refs
        case closed
    }
}

struct BlobPropertyDef: Codable {
    let type: String  // "blob"
    let description: String?
    let accept: [String]?
    let maxSize: Int?
}

struct BytesPropertyDef: Codable {
    let type: String
    let description: String?
    let maxLength: Int?
    let minLength: Int?
}

struct CIDLinkPropertyDef: Codable {
    let type: String  // "cid-link"
    let description: String?
}

struct UnknownPropertyDef: Codable {
    let type: String  // "unknown"
    let description: String?
}

// MARK: - Parameters, Input, Output, Message, Error

struct ParametersDef: Codable {
    let type: String  // "params"
    let required: [String]?
    let properties: [String: PropertyDef]?
}

struct OutputDef: Codable {
    let encoding: String
    let schema: PropertyDef?
    let description: String?
}

struct InputDef: Codable {
    let encoding: String
    let schema: PropertyDef?
    let description: String?
}

struct MessageDef: Codable {
    let schema: PropertyDef?
}

struct ErrorDef: Codable {
    let name: String
    let description: String?
}

// MARK: - Standalone Definition Types

struct TokenDef: Codable {
    let type: String
    let description: String?
}

struct StringDef: Codable {
    let type: String
    let description: String?
    let knownValues: [String]?
}

struct ArrayDef: Codable {
    let type: String
    let description: String?
    let items: PropertyDef
}

// MARK: - Parser

/// Parses Lexicon JSON files from a directory tree.
struct LexiconParser {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    /// Recursively discover all `.json` files under `path`, parse each as a
    /// ``LexiconDocument``, and return them sorted by NSID.
    func parseDirectory(at path: String) throws -> [LexiconDocument] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: path) else {
            throw LexiconParserError.directoryNotFound(path)
        }

        var documents: [LexiconDocument] = []
        while let relativePath = enumerator.nextObject() as? String {
            guard relativePath.hasSuffix(".json") else { continue }
            let fullPath = (path as NSString).appendingPathComponent(relativePath)
            do {
                let doc = try parseFile(at: fullPath)
                documents.append(doc)
            } catch {
                // Print a warning but continue processing other files.
                print("Warning: failed to parse \(fullPath): \(error)")
            }
        }

        return documents.sorted { $0.id < $1.id }
    }

    /// Parse a single Lexicon JSON file.
    func parseFile(at path: String) throws -> LexiconDocument {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        return try decoder.decode(LexiconDocument.self, from: data)
    }
}

// MARK: - Errors

enum LexiconParserError: Error, CustomStringConvertible {
    case directoryNotFound(String)

    var description: String {
        switch self {
        case .directoryNotFound(let path):
            return "Lexicon directory not found: \(path)"
        }
    }
}
