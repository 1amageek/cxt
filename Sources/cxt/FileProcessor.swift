import Foundation

/// File information model
struct FileInfo: Equatable {
    let url: URL
    let relativePath: String
}

/// Class responsible for file processing operations
struct FileProcessor {
    /// Logger function for optional verbose output
    private let logger: (String) -> Void
    
    /// Initialize with a logger function
    /// - Parameter logger: Function to handle log messages
    init(logger: @escaping (String) -> Void = { _ in }) {
        self.logger = logger
    }
    
    /// Scan directory for files with specified extensions
    /// - Parameters:
    ///   - path: Directory path to scan
    ///   - extensions: File extensions to look for
    /// - Returns: Array of matched files
    func scanDirectory(path: String, extensions: [String]) throws -> [FileInfo] {
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw RuntimeError("Failed to access directory: \(path)")
        }
        
        var files: [FileInfo] = []
        
        for case let fileURL as URL in enumerator {
            guard extensions.contains(fileURL.pathExtension) else { continue }
            
            // Calculate relative path from base directory
            let fullPath = fileURL.path
            let relativePath: String
            
            if fullPath == path {
                relativePath = URL(fileURLWithPath: path).lastPathComponent
            } else if fullPath.hasPrefix(path) {
                // Calculate relative path from base directory
                if path.hasSuffix("/") {
                    relativePath = String(fullPath.dropFirst(path.count))
                } else {
                    relativePath = String(fullPath.dropFirst(path.count + 1))
                }
            } else {
                relativePath = fullPath
            }
            
            files.append(FileInfo(url: fileURL, relativePath: relativePath))
        }
        
        // Sort files by path for consistent output
        let sortedFiles = files.sorted { $0.relativePath < $1.relativePath }
        
        logger("Found \(sortedFiles.count) matching files")
        
        return sortedFiles
    }
    
    /// Generate formatted content from files
    /// - Parameters:
    ///   - files: List of files to process
    ///   - basePath: Base directory path
    ///   - extensions: File extensions included
    /// - Returns: Formatted content string
    func generateContent(
        files: [FileInfo],
        basePath: String,
        extensions: [String]
    ) -> String {
        // Get current date for frontmatter
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let currentDate = dateFormatter.string(from: Date())
        
        // Start building the content
        var outputContent = """
        ---
        created_at: \(currentDate)
        extensions: [\(extensions.map { "." + $0 }.joined(separator: ", "))]
        base_path: \(basePath)
        ---
        
        """
        
        // Process each file
        for file in files {
            do {
                let content = try String(contentsOf: file.url, encoding: .utf8)
                
                // Add file section with markdown formatting
                outputContent += """
                
                # \(file.relativePath)
                
                ```\(file.url.pathExtension)
                \(content)
                ```
                
                """
            } catch {
                logger("Warning: Could not read file \(file.url.path): \(error.localizedDescription)")
            }
        }
        
        return outputContent
    }
    
    /// Extract relevant files based on provided paths
    /// - Parameters:
    ///   - paths: Paths to match against
    ///   - basePath: Base directory path
    ///   - allFiles: All available files
    /// - Returns: Filtered list of files
    func extractRelevantFiles(
        fromPaths paths: [String],
        basePath: String,
        allFiles: [FileInfo]
    ) -> [FileInfo] {
        // Normalize paths for comparison
        let normalizedPaths = paths.map { path -> String in
            var normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Handle paths that might start with the base path
            if normalizedPath.hasPrefix(basePath) {
                if basePath.hasSuffix("/") {
                    normalizedPath = String(normalizedPath.dropFirst(basePath.count))
                } else {
                    normalizedPath = String(normalizedPath.dropFirst(basePath.count + 1))
                }
            }
            
            return normalizedPath
        }
        
        // Find files that match the normalized paths
        return allFiles.filter { file in
            for normalizedPath in normalizedPaths {
                // Check for exact match or if the path is a substring
                if file.relativePath == normalizedPath ||
                    file.relativePath.hasSuffix(normalizedPath) ||
                    // Handle partial paths (e.g., "MyFile.swift" matching "Sources/MyFile.swift")
                    normalizedPath.hasSuffix(file.relativePath) {
                    return true
                }
            }
            return false
        }
    }
}
