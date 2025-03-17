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
    
    /// Flag to control whether ignore files are respected
    private let respectIgnoreFiles: Bool
    
    /// Additional ignore patterns from command line
    private let additionalPatterns: [String]
    
    /// Initialize with a logger function and ignore options
    /// - Parameters:
    ///   - logger: Function to handle log messages
    ///   - respectIgnoreFiles: Whether to respect .gitignore and .clineignore files
    ///   - additionalPatterns: Additional ignore patterns
    init(
        logger: @escaping (String) -> Void = { _ in },
        respectIgnoreFiles: Bool = true,
        additionalPatterns: [String] = []
    ) {
        self.logger = logger
        self.respectIgnoreFiles = respectIgnoreFiles
        self.additionalPatterns = additionalPatterns
    }
    
    /// Scan directory for files with specified extensions
    /// - Parameters:
    ///   - path: Directory path to scan
    ///   - extensions: File extensions to look for
    /// - Returns: Array of matched files
    func scanDirectory(path: String, extensions: [String]) throws -> [FileInfo] {
        let fileManager = FileManager.default
        let directoryURL = URL(fileURLWithPath: path)
        
        // まず、ディレクトリが存在するか確認
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw RuntimeError("Path does not exist or is not a directory: \(path)")
        }
        
        // Build the ignore matcher
        let ignoreMatcher = IgnoreMatcher(
            basePath: path,
            respectIgnoreFiles: respectIgnoreFiles,
            logger: logger,
            additionalPatterns: additionalPatterns
        )
        
        // Load default ignore patterns
        ignoreMatcher.loadDefaultIgnorePatterns()
        
        // Find all .gitignore and .clineignore files first if needed
        if respectIgnoreFiles {
            try findAndLoadIgnoreFiles(in: path, ignoreMatcher: ignoreMatcher)
        }
        
        var files: [FileInfo] = []
        var visitedPaths = Set<String>()
        
        // Now scan for actual files
        try scanForFiles(
            directoryPath: path,
            basePath: path,
            extensions: extensions,
            ignoreMatcher: ignoreMatcher,
            files: &files,
            visitedPaths: &visitedPaths
        )
        
        // Sort files by path for consistent output
        let sortedFiles = files.sorted { $0.relativePath < $1.relativePath }
        
        logger("Found \(sortedFiles.count) matching files")
        
        return sortedFiles
    }
    
    /// Find all .gitignore and .clineignore files in the directory tree
    /// - Parameters:
    ///   - directoryPath: Directory to scan
    ///   - ignoreMatcher: The ignore matcher to update
    private func findAndLoadIgnoreFiles(in directoryPath: String, ignoreMatcher: IgnoreMatcher) throws {
        let fileManager = FileManager.default
        let directoryURL = URL(fileURLWithPath: directoryPath)
        
        // Check for ignore files in this directory
        ignoreMatcher.loadIgnoreFilesAt(directoryPath)
        
        // Recursively check subdirectories
        let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.isDirectoryKey], options: [])
        
        for item in contents {
            let isDirectory = (try item.resourceValues(forKeys: [.isDirectoryKey])).isDirectory ?? false
            if isDirectory {
                // Skip if this directory should be ignored
                let relativePath = item.path.replacingOccurrences(of: ignoreMatcher.basePath, with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                
                if !ignoreMatcher.shouldIgnorePath(relativePath) {
                    try findAndLoadIgnoreFiles(in: item.path, ignoreMatcher: ignoreMatcher)
                }
            }
        }
    }
    
    /// Scan directory for files with matching extensions
    /// - Parameters:
    ///   - directoryPath: Current directory to scan
    ///   - basePath: Base directory path for relative path calculation
    ///   - extensions: File extensions to match
    ///   - ignoreMatcher: The ignore matcher
    ///   - files: Array to collect matching files
    ///   - visitedPaths: Set of canonical paths already visited
    private func scanForFiles(
        directoryPath: String,
        basePath: String,
        extensions: [String],
        ignoreMatcher: IgnoreMatcher,
        files: inout [FileInfo],
        visitedPaths: inout Set<String>
    ) throws {
        let fileManager = FileManager.default
        let directoryURL = URL(fileURLWithPath: directoryPath)
        
        // Resolve symlinks to prevent loops
        let canonicalPath = directoryURL.resolvingSymlinksInPath().path
        
        // Skip if already visited
        if visitedPaths.contains(canonicalPath) {
            return
        }
        visitedPaths.insert(canonicalPath)
        
        // Get relative path for this directory
        let dirRelativePath = directoryPath.replacingOccurrences(of: basePath, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // Skip if this directory should be ignored
        if !dirRelativePath.isEmpty && ignoreMatcher.shouldIgnorePath(dirRelativePath) {
            logger("Ignoring directory: \(dirRelativePath)")
            return
        }
        
        // Get directory contents
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            logger("Warning: Could not read directory \(directoryPath): \(error.localizedDescription)")
            return
        }
        
        // Process each item
        for item in contents {
            // Get relative path
            let relativePath = item.path.replacingOccurrences(of: basePath, with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            
            // Skip if matches ignore patterns
            if ignoreMatcher.shouldIgnorePath(relativePath) {
                logger("Ignoring: \(relativePath)")
                continue
            }
            
            do {
                let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
                
                if resourceValues.isDirectory == true {
                    // Process subdirectory
                    try scanForFiles(
                        directoryPath: item.path,
                        basePath: basePath,
                        extensions: extensions,
                        ignoreMatcher: ignoreMatcher,
                        files: &files,
                        visitedPaths: &visitedPaths
                    )
                } else if resourceValues.isRegularFile == true {
                    // Check if file has matching extension
                    if extensions.contains(item.pathExtension.lowercased()) {
                        files.append(FileInfo(url: item, relativePath: relativePath))
                        logger("Found file: \(relativePath)")
                    }
                }
            } catch {
                logger("Warning: Could not access \(item.path): \(error.localizedDescription)")
            }
        }
    }
    
    // その他のメソッドは変更なし
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
