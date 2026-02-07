import Foundation

/// Converts Lexicon names to Swift-idiomatic names
struct NamingStrategy {

    /// Reserved words in Swift that must be escaped with backticks when used as identifiers.
    static let swiftReservedWords: Set<String> = [
        "associatedtype", "class", "deinit", "enum", "extension", "fileprivate",
        "func", "import", "init", "inout", "internal", "let", "open", "operator",
        "private", "protocol", "public", "rethrows", "static", "struct",
        "subscript", "typealias", "var",
        "break", "case", "continue", "default", "defer", "do", "else",
        "fallthrough", "for", "guard", "if", "in", "repeat", "return",
        "switch", "where", "while",
        "as", "Any", "catch", "false", "is", "nil", "super", "self", "Self",
        "throw", "throws", "true", "try",
        "type", "description",
    ]

    // MARK: - Public API

    /// Convert an NSID and definition name to a Swift struct/enum name.
    ///
    /// - Parameters:
    ///   - nsid: The Lexicon NSID, e.g. `"app.bsky.feed.post"`.
    ///   - defName: The definition key inside the document, e.g. `"main"` or `"replyRef"`.
    /// - Returns: A PascalCase Swift type name such as `"AppBskyFeedPost"` or
    ///   `"AppBskyFeedPostReplyRef"`.
    func structName(for nsid: String, defName: String) -> String {
        let base = pascalCase(fromNSID: nsid)
        if defName == "main" {
            return base
        }
        return base + capitalizeFirst(defName)
    }

    /// Convert a Lexicon enum string value to a Swift `case` name.
    ///
    /// Strips leading punctuation such as `!`, converts kebab-case and other
    /// separators to camelCase, and escapes Swift reserved words.
    func enumCaseName(_ value: String) -> String {
        var cleaned = value
        // Strip leading non-alphanumeric characters (e.g. "!" in "!no-unauthenticated")
        while let first = cleaned.first, !first.isLetter && !first.isNumber {
            cleaned.removeFirst()
        }
        if cleaned.isEmpty {
            return "_empty"
        }
        let result = camelCaseFromComponents(splitIdentifier(cleaned))
        return escaped(result)
    }

    /// Convert a Lexicon property key to a camelCase Swift property name.
    func propertyName(_ key: String) -> String {
        let result = camelCaseFromComponents(splitIdentifier(key))
        return escaped(result)
    }

    /// Derive a file name from an NSID.
    ///
    /// `"app.bsky.feed.post"` becomes `"AppBskyFeedPost.swift"`.
    func fileName(for nsid: String) -> String {
        return pascalCase(fromNSID: nsid) + ".swift"
    }

    // MARK: - Helpers

    /// Convert an NSID to a PascalCase string by capitalizing each dot-separated segment.
    func pascalCase(fromNSID nsid: String) -> String {
        nsid
            .split(separator: ".")
            .map { capitalizeFirst(String($0)) }
            .joined()
    }

    /// Split an identifier on common word boundaries (hyphens, underscores,
    /// camelCase transitions) and return lowercase components.
    private func splitIdentifier(_ identifier: String) -> [String] {
        // First split on hyphens and underscores.
        let roughParts = identifier
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map(String.init)

        var components: [String] = []
        for part in roughParts {
            // Split on camelCase boundaries: insert a break before each uppercase
            // letter that follows a lowercase letter.
            var current = ""
            for (index, char) in part.enumerated() {
                if char.isUppercase && index > 0 {
                    let prevIndex = part.index(part.startIndex, offsetBy: index - 1)
                    if part[prevIndex].isLowercase {
                        components.append(current.lowercased())
                        current = ""
                    }
                }
                current.append(char)
            }
            if !current.isEmpty {
                components.append(current.lowercased())
            }
        }
        return components
    }

    /// Join components into a camelCase string (first component lowercase,
    /// subsequent components capitalised).
    private func camelCaseFromComponents(_ components: [String]) -> String {
        guard let first = components.first else { return "" }
        return first.lowercased()
            + components.dropFirst().map { capitalizeFirst($0) }.joined()
    }

    /// Capitalise the first character of a string.
    private func capitalizeFirst(_ string: String) -> String {
        guard let first = string.first else { return string }
        return first.uppercased() + string.dropFirst()
    }

    /// Escape reserved words with backticks.
    private func escaped(_ name: String) -> String {
        if Self.swiftReservedWords.contains(name) {
            return "`\(name)`"
        }
        return name
    }
}
