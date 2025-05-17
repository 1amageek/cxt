import Foundation
import ArgumentParser

#if canImport(AppKit)
import AppKit
#endif

@main
struct CXT: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cxt",
        abstract: "Concatenate files for easy sharing",
        discussion: """
        This command searches for files with specified extensions and concatenates them with markdown formatting.
        By default, it respects .gitignore and .clineignore files at every directory level.
        
        Ignore patterns:
        - Directory patterns like "components/ui" will match both that exact directory and all its subdirectories
        - You can use patterns like "*.log" to ignore all log files
        - Path patterns with slashes will match at any directory level
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
        
        // Parse extensions
        let extensions = fileExtensions.split(separator: ",").map(String.init)
        
        // Resolve directory path
        let resolvedPath = (directoryPath as NSString).expandingTildeInPath
        
        logger("Searching for files with extensions: \(extensions.joined(separator: ", "))")
        logger("Base directory: \(resolvedPath)")
        
        // Parse additional ignore patterns
        var additionalPatternsArray: [String] = []
        if let patterns = ignorePatterns {
            additionalPatternsArray = patterns.split(separator: ",").map(String.init)
            logger("Additional ignore patterns: \(additionalPatternsArray.joined(separator: ", "))")
        }
        
        // Create file processor (always respect ignore files)
        let fileProcessor = FileProcessor(
            logger: logger,
            respectIgnoreFiles: true,
            additionalPatterns: additionalPatternsArray
        )
        
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
        
        // Final content variable
        let finalContent = initialContent
        let processedFiles = files
        
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
