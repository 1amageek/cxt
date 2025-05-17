import Foundation
import ArgumentParser

#if canImport(AppKit)
import AppKit
#endif

@main
struct CXT: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cxt",
        abstract: "Concatenate files and extract related paths for SwiftAgent",
        discussion: """
        This command searches for files with specified extensions, concatenates them with markdown formatting,
        and extracts related paths based on the provided prompt. By default, it respects .gitignore and .clineignore files
        at every directory level.
        
        Ignore patterns:
        - Directory patterns like "components/ui" will match both that exact directory and all its subdirectories
        - You can use patterns like "*.log" to ignore all log files
        - Path patterns with slashes will match at any directory level
        """
    )
    
    @Argument(
        help: "File extensions to search for (comma-separated, without dots) or comma-separated file list when directory is omitted"
    )
    var fileExtensions: String

    @Argument(
        help: "Directory path to search in (supports ~ for home directory)"
    )
    var directoryPath: String?
    
    @Argument(
        help: "Prompt to identify related files",
        completion: .none
    )
    var prompt: String?
    
    @Flag(
        name: [.short, .long],
        help: "Enable verbose output"
    )
    var verbose: Bool = false
    
    @Option(
        name: [.short, .long],
        help: "Additional ignore patterns (comma-separated, e.g. 'node_modules,components/ui')"
    )
    var ignorePatterns: String?
    
    mutating func run() async throws {
        let logger = verbose ? { print($0) } : { _ in }

        func finalize(
            files: [FileInfo],
            basePath: String,
            extensions: [String]
        ) async throws {
            let initialContent = fileProcessor.generateContent(
                files: files,
                basePath: basePath,
                extensions: extensions
            )

            var finalContent = initialContent
            var processedFiles = files

            if let userPrompt = prompt, !userPrompt.isEmpty {
                do {
                    logger("Running context agent with prompt: \(userPrompt)")

                    let context = try await ContextAgent().run(
                        """
                        instruction: \(userPrompt)

                        context:
                        \(initialContent)
                        """
                    )

                    logger("Context agent returned \(context.paths.count) paths")
                    context.paths.forEach { logger("- \($0)") }

                    if !context.paths.isEmpty {
                        let relevantFiles = fileProcessor.extractRelevantFiles(
                            fromPaths: context.paths,
                            basePath: basePath,
                            allFiles: files
                        )

                        logger("Identified \(relevantFiles.count) relevant files")

                        finalContent = fileProcessor.generateContent(
                            files: relevantFiles,
                            basePath: basePath,
                            extensions: extensions
                        )

                        processedFiles = relevantFiles

                        fputs("Filtered content based on context:\n", stderr)
                        for file in relevantFiles {
                            fputs("  - \(file.relativePath)\n", stderr)
                        }
                    } else {
                        fputs("Context agent returned no relevant paths\n", stderr)
                    }
                } catch {
                    fputs("Error while running context agent: \(error.localizedDescription)\n", stderr)
                }
            }

            #if canImport(AppKit)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(finalContent, forType: .string)
            logger("Content copied to clipboard")
            #endif

            let fileCount = processedFiles.count
            let extensionsStr = extensions.map { "." + $0 }.joined(separator: ", ")
            fputs("✨ Done! Processed \(fileCount) files (\(extensionsStr))\n", stderr)
        }

        var additionalPatternsArray: [String] = []
        if let patterns = ignorePatterns {
            additionalPatternsArray = patterns.split(separator: ",").map(String.init)
            logger("Additional ignore patterns: \(additionalPatternsArray.joined(separator: ", "))")
        }

        let fileProcessor = FileProcessor(
            logger: logger,
            respectIgnoreFiles: true,
            additionalPatterns: additionalPatternsArray
        )

        if let dirPath = directoryPath {
            let extensions = fileExtensions.split(separator: ",").map(String.init)
            let resolvedPath = (dirPath as NSString).expandingTildeInPath

            logger("Searching for files with extensions: \(extensions.joined(separator: ", "))")
            logger("Base directory: \(resolvedPath)")

            let files = try fileProcessor.scanDirectory(
                path: resolvedPath,
                extensions: extensions
            )

            try await finalize(files: files, basePath: resolvedPath, extensions: extensions)
        } else {
            let basePath = FileManager.default.currentDirectoryPath

            logger("Processing file list: \(fileExtensions)")

            let paths = fileExtensions.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

            let files: [FileInfo] = paths.map { path in
                let expanded = (path as NSString).expandingTildeInPath
                let absolute = expanded.hasPrefix("/") ? expanded : basePath + "/" + expanded
                let url = URL(fileURLWithPath: absolute)
                return FileInfo(url: url, relativePath: path)
            }

            let exts = paths.map { URL(fileURLWithPath: String($0)).pathExtension.lowercased() }.filter { !$0.isEmpty }
            let uniqueExts = Array(Set(exts)).sorted()

            try await finalize(files: files, basePath: basePath, extensions: uniqueExts)
        }
    }
}

/// General runtime errors
struct RuntimeError: Error, CustomStringConvertible {
    let description: String
    
    init(_ description: String) {
        self.description = description
    }
}
