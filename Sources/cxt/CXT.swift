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
        and extracts related paths based on the provided prompt.
        """
    )
    
    @Argument(
        help: "File extensions to search for (comma-separated, without dots)"
    )
    var fileExtensions: String
    
    @Argument(
        help: "Directory path to search in (supports ~ for home directory)"
    )
    var directoryPath: String
    
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
    
    mutating func run() async throws {
        let logger = verbose ? { print($0) } : { _ in }
        
        // Create file processor
        let fileProcessor = FileProcessor(logger: logger)
        
        // Parse extensions
        let extensions = fileExtensions.split(separator: ",").map(String.init)
        
        // Resolve directory path
        let resolvedPath = (directoryPath as NSString).expandingTildeInPath
        
        logger("Searching for files with extensions: \(extensions.joined(separator: ", "))")
        logger("Base directory: \(resolvedPath)")
        
        // Scan directory for matching files
        let files = try fileProcessor.scanDirectory(
            path: resolvedPath,
            extensions: extensions
        )
        
        // Generate initial content
        let initialContent = fileProcessor.generateContent(
            files: files,
            basePath: resolvedPath,
            extensions: extensions
        )
        
        // Final content variable - will be updated if prompt is provided
        var finalContent = initialContent
        var processedFiles = files
        
        // Process with context agent if prompt is provided
        if let userPrompt = prompt, !userPrompt.isEmpty {
            do {
                logger("Running context agent with prompt: \(userPrompt)")
                
                // Get context based on prompt and content
                let context = try await ContextAgent().run(
                    """
                    instruction: \(userPrompt)
                    
                    context:
                    \(initialContent)
                    """
                )
                
                logger("Context agent returned \(context.paths.count) paths")
                context.paths.forEach { logger("- \($0)") }
                
                // Only proceed if we actually got paths back
                if !context.paths.isEmpty {
                    // Extract relevant files based on returned paths
                    let relevantFiles = fileProcessor.extractRelevantFiles(
                        fromPaths: context.paths,
                        basePath: resolvedPath,
                        allFiles: files
                    )
                    
                    logger("Identified \(relevantFiles.count) relevant files")
                    
                    // Generate final content based on relevant files
                    finalContent = fileProcessor.generateContent(
                        files: relevantFiles,
                        basePath: resolvedPath,
                        extensions: extensions
                    )
                    
                    // Update processed files
                    processedFiles = relevantFiles
                    
                    // Output the filtered paths
                    fputs("Filtered content based on context:\n", stderr)
                    for file in relevantFiles {
                        fputs("  - \(file.relativePath)\n", stderr)
                    }
                } else {
                    fputs("Context agent returned no relevant paths\n", stderr)
                }
            } catch {
                fputs("Error while running context agent: \(error.localizedDescription)\n", stderr)
                // Continue with original content if context agent fails
            }
        }
        
        // Copy to clipboard on macOS
#if canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(finalContent, forType: .string)
        logger("Content copied to clipboard")
#endif
        
        // Generate success message to stderr
        let fileCount = processedFiles.count
        let extensionsStr = extensions.map { "." + $0 }.joined(separator: ", ")
        fputs("✨ Done! Processed \(fileCount) files (\(extensionsStr))\n", stderr)
    }
}

/// General runtime errors
struct RuntimeError: Error, CustomStringConvertible {
    let description: String
    
    init(_ description: String) {
        self.description = description
    }
}
