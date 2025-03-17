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
        let directoryURL = URL(fileURLWithPath: path)
        
        // まず、ディレクトリが存在するか確認
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw RuntimeError("Path does not exist or is not a directory: \(path)")
        }
        
        // Load ignore rules
        let ignorePatterns = try loadIgnorePatterns(basePath: path)
        logger("Loaded \(ignorePatterns.count) ignore patterns")
        
        // ディレクトリの内容を再帰的に列挙
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw RuntimeError("Failed to access directory: \(path)")
        }
        
        var files: [FileInfo] = []
        
        for case let fileURL as URL in enumerator {
            // Get relative path for ignore pattern matching
            let relativePath = fileURL.path.replacingOccurrences(of: directoryURL.path, with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            
            // Skip if matches ignore patterns
            if shouldIgnorePath(relativePath, patterns: ignorePatterns) {
                logger("Ignoring: \(relativePath)")
                if try fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }
            
            do {
                // ファイルかどうか確認
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if resourceValues.isRegularFile == true {
                    // 拡張子が対象かどうか確認
                    if extensions.contains(fileURL.pathExtension.lowercased()) {
                        files.append(FileInfo(url: fileURL, relativePath: relativePath))
                        logger("Found file: \(relativePath)")
                    }
                }
            } catch {
                logger("Error reading file attributes: \(error.localizedDescription)")
            }
        }
        
        // Sort files by path for consistent output
        let sortedFiles = files.sorted { $0.relativePath < $1.relativePath }
        
        logger("Found \(sortedFiles.count) matching files")
        
        return sortedFiles
    }
    
    /// Load ignore patterns from .gitignore and .clineignore files
    /// - Parameter basePath: Base directory path to search for ignore files
    /// - Returns: Array of ignore patterns
    private func loadIgnorePatterns(basePath: String) throws -> [String] {
        var patterns: [String] = []
        
        // Common directories/paths to ignore by default
        let defaultIgnores = [
            "node_modules/",
            ".git/",
            ".DS_Store",
            "*.xcodeproj",
            ".build/"
        ]
        patterns.append(contentsOf: defaultIgnores)
        
        // Load patterns from .gitignore
        let gitignorePath = URL(fileURLWithPath: basePath).appendingPathComponent(".gitignore").path
        if FileManager.default.fileExists(atPath: gitignorePath) {
            do {
                let gitignoreContent = try String(contentsOfFile: gitignorePath, encoding: .utf8)
                let gitPatterns = parseIgnoreFile(content: gitignoreContent)
                patterns.append(contentsOf: gitPatterns)
                logger("Loaded \(gitPatterns.count) patterns from .gitignore")
            } catch {
                logger("Warning: Could not read .gitignore: \(error.localizedDescription)")
            }
        }
        
        // Load patterns from .clineignore
        let clineignorePath = URL(fileURLWithPath: basePath).appendingPathComponent(".clineignore").path
        if FileManager.default.fileExists(atPath: clineignorePath) {
            do {
                let clineignoreContent = try String(contentsOfFile: clineignorePath, encoding: .utf8)
                let clinePatterns = parseIgnoreFile(content: clineignoreContent)
                patterns.append(contentsOf: clinePatterns)
                logger("Loaded \(clinePatterns.count) patterns from .clineignore")
            } catch {
                logger("Warning: Could not read .clineignore: \(error.localizedDescription)")
            }
        }
        
        return patterns
    }
    
    /// Parse an ignore file content into patterns
    /// - Parameter content: Content of the ignore file
    /// - Returns: Array of patterns
    private func parseIgnoreFile(content: String) -> [String] {
        return content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") } // Remove empty lines and comments
    }
    
    /// Check if a path should be ignored based on patterns
    /// - Parameters:
    ///   - path: Path to check
    ///   - patterns: Ignore patterns to match against
    /// - Returns: True if path should be ignored
    private func shouldIgnorePath(_ path: String, patterns: [String]) -> Bool {
        for pattern in patterns {
            if matchesIgnorePattern(path: path, pattern: pattern) {
                return true
            }
        }
        return false
    }
    
    /// Match a path against an ignore pattern
    /// - Parameters:
    ///   - path: Path to check
    ///   - pattern: Ignore pattern
    /// - Returns: True if path matches pattern
    private func matchesIgnorePattern(path: String, pattern: String) -> Bool {
        var patternToUse = pattern
        
        // Handle directory-specific patterns (ending with /)
        let isDirectoryPattern = pattern.hasSuffix("/")
        if isDirectoryPattern {
            patternToUse = String(pattern.dropLast())
        }
        
        // Convert glob pattern to regex pattern
        var regexPattern = "^"
        
        // Handle patterns that start with **/
        if patternToUse.hasPrefix("**/") {
            patternToUse = String(patternToUse.dropFirst(3))
            regexPattern += ".*"
        }
        
        // Process the rest of the pattern
        var i = 0
        while i < patternToUse.count {
            let index = patternToUse.index(patternToUse.startIndex, offsetBy: i)
            let char = patternToUse[index]
            
            if char == "*" {
                if i + 1 < patternToUse.count && patternToUse[patternToUse.index(index, offsetBy: 1)] == "*" {
                    // ** matches any number of directories
                    if i + 2 < patternToUse.count && patternToUse[patternToUse.index(index, offsetBy: 2)] == "/" {
                        regexPattern += "(.*/|)"
                        i += 3
                    } else {
                        regexPattern += ".*"
                        i += 2
                    }
                } else {
                    // * matches any character except /
                    regexPattern += "[^/]*"
                    i += 1
                }
            } else if char == "?" {
                // ? matches any single character except /
                regexPattern += "[^/]"
                i += 1
            } else if char == "[" {
                // Character class
                regexPattern += "["
                i += 1
                
                // If next char is !, it's a negated class
                if i < patternToUse.count && patternToUse[patternToUse.index(patternToUse.startIndex, offsetBy: i)] == "!" {
                    regexPattern += "^"
                    i += 1
                }
                
                // Add characters until we find a closing ]
                while i < patternToUse.count && patternToUse[patternToUse.index(patternToUse.startIndex, offsetBy: i)] != "]" {
                    regexPattern += String(patternToUse[patternToUse.index(patternToUse.startIndex, offsetBy: i)])
                    i += 1
                }
                
                if i < patternToUse.count {
                    regexPattern += "]"
                    i += 1
                }
            } else if char == "\\" {
                // Escape the next character
                i += 1
                if i < patternToUse.count {
                    regexPattern += "\\" + String(patternToUse[patternToUse.index(patternToUse.startIndex, offsetBy: i)])
                    i += 1
                }
            } else {
                // Regular character
                regexPattern += "\\" + String(char)
                i += 1
            }
        }
        
        regexPattern += "$"
        
        // Check if path matches the pattern
        do {
            let regex = try NSRegularExpression(pattern: regexPattern, options: [])
            let range = NSRange(location: 0, length: path.utf16.count)
            
            // For directory patterns, check if the path is or contains the directory
            if isDirectoryPattern {
                let directoryPath = patternToUse + "/"
                return path.hasPrefix(directoryPath) || path == patternToUse
            }
            
            return regex.firstMatch(in: path, options: [], range: range) != nil
        } catch {
            logger("Warning: Invalid ignore pattern: \(pattern)")
            
            // Fallback to simple matching for broken patterns
            let simplifiedPattern = patternToUse
                .replacingOccurrences(of: "**/", with: "")
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "*", with: "")
            
            return path.contains(simplifiedPattern)
        }
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
