import Foundation

/// Class responsible for handling ignore patterns
class IgnoreMatcher {
    /// Base directory path
    let basePath: String
    
    /// Flag to control whether ignore files are respected
    private let respectIgnoreFiles: Bool
    
    /// Logger function
    private let logger: (String) -> Void
    
    /// Additional ignore patterns
    private let additionalPatterns: [String]
    
    /// Dictionary of directory path to ignore patterns
    internal var ignorePatterns: [String: [String]] = [:]
    
    /// Default ignore patterns (applied globally)
    internal var defaultPatterns: [String] = []
    
    /// Path matcher for handling glob pattern matching
    private let pathMatcher: PathMatcher
    
    /// Initialize with base path and ignore options
    /// - Parameters:
    ///   - basePath: Base directory path
    ///   - respectIgnoreFiles: Whether to respect .gitignore and .clineignore files
    ///   - logger: Logger function
    ///   - additionalPatterns: Additional ignore patterns
    init(basePath: String, respectIgnoreFiles: Bool, logger: @escaping (String) -> Void, additionalPatterns: [String]) {
        // Normalize base path to ensure consistent handling
        if basePath.hasSuffix("/") {
            self.basePath = basePath
        } else {
            self.basePath = basePath + "/"
        }
        
        self.respectIgnoreFiles = respectIgnoreFiles
        self.logger = logger
        self.additionalPatterns = additionalPatterns
        self.pathMatcher = PathMatcher(logger: logger)
    }
    
    /// Load default ignore patterns
    func loadDefaultIgnorePatterns() {
        // Common directories/files to ignore
        let commonIgnores = [
            "node_modules/",
            ".git/",
            ".DS_Store",
            "*.xcodeproj",
            ".build/"
        ]
        
        // Add common patterns and additional patterns
        defaultPatterns.append(contentsOf: commonIgnores)
        
        // Normalize additional patterns and add them
        let normalizedAdditionalPatterns = pathMatcher.normalizePatterns(additionalPatterns)
        defaultPatterns.append(contentsOf: normalizedAdditionalPatterns)
        
        logger("Loaded \(defaultPatterns.count) default and additional ignore patterns")
    }
    
    /// Load ignore files at a specific directory
    /// - Parameter directoryPath: Directory path to check for ignore files
    func loadIgnoreFilesAt(_ directoryPath: String) {
        var patterns: [String] = []
        
        // Check for .gitignore
        let gitignorePath = URL(fileURLWithPath: directoryPath).appendingPathComponent(".gitignore").path
        if FileManager.default.fileExists(atPath: gitignorePath) {
            do {
                let gitignoreContent = try String(contentsOfFile: gitignorePath, encoding: .utf8)
                let gitPatterns = parseIgnoreFile(content: gitignoreContent)
                patterns.append(contentsOf: gitPatterns)
                logger("Loaded \(gitPatterns.count) patterns from .gitignore at \(directoryPath)")
            } catch {
                logger("Warning: Could not read .gitignore at \(directoryPath): \(error.localizedDescription)")
            }
        }
        
        // Check for .clineignore
        let clineignorePath = URL(fileURLWithPath: directoryPath).appendingPathComponent(".clineignore").path
        if FileManager.default.fileExists(atPath: clineignorePath) {
            do {
                let clineignoreContent = try String(contentsOfFile: clineignorePath, encoding: .utf8)
                let clinePatterns = parseIgnoreFile(content: clineignoreContent)
                patterns.append(contentsOf: clinePatterns)
                logger("Loaded \(clinePatterns.count) patterns from .clineignore at \(directoryPath)")
            } catch {
                logger("Warning: Could not read .clineignore at \(directoryPath): \(error.localizedDescription)")
            }
        }
        
        // Store patterns for this directory if any were found
        if !patterns.isEmpty {
            // Normalize patterns before storing
            let normalizedPatterns = pathMatcher.normalizePatterns(patterns)
            ignorePatterns[directoryPath] = normalizedPatterns
        }
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
    /// - Parameter relativePath: Relative path to check
    /// - Returns: True if path should be ignored
    func shouldIgnorePath(_ relativePath: String) -> Bool {
        if relativePath.isEmpty {
            return false
        }
        
        // defaultPatterns のチェック
        for pattern in defaultPatterns {
            if pathMatcher.matches(path: relativePath, pattern: pattern) {
                return true
            }
        }
        
        // ignoreFiles から読み込んだパターンもチェック
        for (_, patterns) in ignorePatterns {
            for pattern in patterns {
                if pathMatcher.matches(path: relativePath, pattern: pattern) {
                    return true
                }
            }
        }
        
        return false
    }
}
