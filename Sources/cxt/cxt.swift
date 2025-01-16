import Foundation
import ArgumentParser
import AppKit

@main
struct CXT: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cxt",
        abstract: "Concatenate files with specified extensions and copy to clipboard as markdown"
    )
    
    @Argument(
        help: "File extensions to search for (comma-separated, without dots)",
        completion: .none
    )
    var fileExtensions: String
    
    @Argument(
        help: "Directory path to search in (supports ~ for home directory)",
        completion: .directory
    )
    var directoryPath: String
    
    mutating func run() throws {
        let fileManager = FileManager.default
        let resolvedPath = (directoryPath as NSString).expandingTildeInPath
        let extensions = fileExtensions.split(separator: ",").map(String.init)
        
        // Get current date for frontmatter
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let currentDate = dateFormatter.string(from: Date())
        
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: resolvedPath),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw RuntimeError("Failed to access directory: \(resolvedPath)")
        }
        
        // Start with frontmatter
        var markdownContent = """
        ---
        created_at: \(currentDate)
        extensions: [\(extensions.map { "." + $0 }.joined(separator: ", "))]
        base_path: \(resolvedPath)
        ---
        
        """
        
        // Collect all matching files first
        var files: [(url: URL, relativePath: String)] = []
        
        for case let fileURL as URL in enumerator {
            guard extensions.contains(fileURL.pathExtension) else { continue }
            
            // Calculate relative path from base directory
            let fullPath = fileURL.path
            let relativePath = String(fullPath.dropFirst(resolvedPath.count + 1)) // +1 for trailing slash
            
            files.append((fileURL, relativePath))
        }
        
        // Sort files by path for consistent output
        files.sort { $0.relativePath < $1.relativePath }
        
        // Process each file
        for (fileURL, relativePath) in files {
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                
                // Add file section with markdown formatting
                markdownContent += """
                
                # \(relativePath)
                
                ```\(fileURL.pathExtension)
                \(content)
                ```
                
                """
            } catch {
                print("Warning: Could not read file \(fileURL.path): \(error.localizedDescription)")
            }
        }
        
        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(markdownContent, forType: .string)
        
        // Generate summary message
        let extensionsStr = extensions.map { "." + $0 }.joined(separator: ", ")
        let fileCount = files.count
        let fileWord = fileCount == 1 ? "file" : "files"
        print("Content from \(fileCount) \(fileWord) with extensions \(extensionsStr) has been copied to clipboard as markdown")
    }
}

struct RuntimeError: Error, CustomStringConvertible {
    let description: String
    
    init(_ description: String) {
        self.description = description
    }
}
