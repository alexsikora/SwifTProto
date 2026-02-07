import PackagePlugin
import Foundation

@main
struct GenerateLexiconPlugin: BuildToolPlugin {
    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) async throws -> [Command] {
        let lexiconDir = context.package.directory.appending("Lexicons")
        let outputDir = context.pluginWorkDirectory.appending("Generated")

        let lexigenTool = try context.tool(named: "lexigen")

        return [
            .buildCommand(
                displayName: "Generate AT Protocol types from Lexicons",
                executable: lexigenTool.path,
                arguments: [
                    "--input", lexiconDir.string,
                    "--output", outputDir.string,
                ],
                inputFiles: [],
                outputFiles: []
            ),
        ]
    }
}
