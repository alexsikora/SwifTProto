import Foundation
import ArgumentParser

@main
struct Lexigen: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lexigen",
        abstract: "Generate Swift types from AT Protocol Lexicon schemas",
        version: "0.1.0"
    )

    @Option(name: .shortAndLong, help: "Path to directory containing Lexicon JSON files")
    var input: String

    @Option(name: .shortAndLong, help: "Output directory for generated Swift files")
    var output: String

    @Option(name: .long, help: "Module name for generated code")
    var moduleName: String = "ATProtoGenerated"

    @Flag(name: .long, help: "Generate with internal access level instead of public")
    var internalAccess: Bool = false

    mutating func run() throws {
        let parser = LexiconParser()
        let documents = try parser.parseDirectory(at: input)

        print("Parsed \(documents.count) lexicon documents")

        var generator = SwiftCodeGenerator(
            namingStrategy: NamingStrategy(),
            typeMapper: TypeMapper()
        )

        if internalAccess {
            generator.accessLevel = "internal"
        }

        let files = generator.generate(documents: documents)

        // Create output directory if needed.
        let fileManager = FileManager.default
        try fileManager.createDirectory(atPath: output, withIntermediateDirectories: true)

        // Write each generated file.
        for file in files {
            let fullPath = (output as NSString).appendingPathComponent(file.path)
            let directory = (fullPath as NSString).deletingLastPathComponent
            try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try file.content.write(toFile: fullPath, atomically: true, encoding: .utf8)
        }

        print("Generated \(files.count) Swift files in \(output)")
    }
}
