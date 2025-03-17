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
        
        defaultPatterns.append(contentsOf: commonIgnores)
        defaultPatterns.append(contentsOf: additionalPatterns)
        
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
            ignorePatterns[directoryPath] = patterns
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
            if matchPatternSimple(pattern: pattern, path: relativePath) {
                return true
            }
        }
        // ignoreFiles から読み込んだパターンもチェック
        for (_, patterns) in ignorePatterns {
            for pattern in patterns {
                if matchPatternSimple(pattern: pattern, path: relativePath) {
                    return true
                }
            }
        }
        return false
    }
    
    /// Simple pattern matching function using glob-to-regex conversion.
    internal func matchPatternSimple(pattern: String, path: String) -> Bool {
        // Convert glob pattern to regular expression
        let regexPattern = globToRegex(pattern)
        do {
            let regex = try NSRegularExpression(pattern: regexPattern)
            let range = NSRange(location: 0, length: path.utf16.count)
            return regex.firstMatch(in: path, options: [], range: range) != nil
        } catch {
            logger("Invalid regex for pattern: \(pattern), error: \(error)")
            return false
        }
    }
    
    /// Convert a glob pattern into a regular expression.
    /// パスにスラッシュが含まれるかどうかで変換方法を分岐します。
    private func globToRegex(_ pattern: String) -> String {
        // パスにスラッシュが含まれない場合、ファイル名部分として全階層でマッチさせる
        if !pattern.contains("/") {
            return "^.*" + nonPathGlobToRegex(pattern) + "$"
        }
        
        var mutablePattern = pattern
        var prefix = "^"
        var trailingSlash = false
        // 末尾がスラッシュの場合は、ディレクトリまたはその配下にマッチさせる
        if mutablePattern.hasSuffix("/") {
            trailingSlash = true
            mutablePattern = String(mutablePattern.dropLast())
        }
        
        // パターンの先頭が "**/" なら、先頭のディレクトリ部分は任意（0文字も可）とする
        if mutablePattern.hasPrefix("**/") {
            prefix += "(?:.*/)?"
            mutablePattern = String(mutablePattern.dropFirst(3))
        }
        
        var regex = ""
        var i = mutablePattern.startIndex
        while i < mutablePattern.endIndex {
            let char = mutablePattern[i]
            if char == "*" {
                let nextIndex = mutablePattern.index(after: i)
                if nextIndex < mutablePattern.endIndex && mutablePattern[nextIndex] == "*" {
                    // "**" -> 任意の文字列（スラッシュ含む）
                    regex += ".*"
                    i = mutablePattern.index(i, offsetBy: 2)
                } else {
                    // "*" -> 任意の文字列（スラッシュを除く）
                    regex += "[^/]*"
                    i = mutablePattern.index(after: i)
                }
            } else if char == "?" {
                regex += "[^/]"
                i = mutablePattern.index(after: i)
            } else if char == "[" {
                // 文字クラスはそのままコピー
                var charClass = ""
                charClass.append(char)
                i = mutablePattern.index(after: i)
                while i < mutablePattern.endIndex && mutablePattern[i] != "]" {
                    charClass.append(mutablePattern[i])
                    i = mutablePattern.index(after: i)
                }
                if i < mutablePattern.endIndex {
                    charClass.append("]")
                    i = mutablePattern.index(after: i)
                }
                regex += charClass
            } else {
                let specialChars = "\\^$.|+(){}"
                if specialChars.contains(char) {
                    regex.append("\\")
                }
                regex.append(char)
                i = mutablePattern.index(after: i)
            }
        }
        
        // 末尾がディレクトリ指定の場合、直後に "/" 以降があってもマッチするようにする
        if trailingSlash {
            regex += "(?:/.*)?"
        }
        return prefix + regex + "$"
    }
    
    /// glob パターン（スラッシュを含まない）の変換
    /// "*" は ".*"、"?" は "." として変換し、正規表現の特殊文字はエスケープします。
    private func nonPathGlobToRegex(_ pattern: String) -> String {
        var regex = ""
        var i = pattern.startIndex
        while i < pattern.endIndex {
            let char = pattern[i]
            if char == "*" {
                regex += ".*"
                i = pattern.index(after: i)
            } else if char == "?" {
                regex += "."
                i = pattern.index(after: i)
            } else if char == "[" {
                var charClass = ""
                charClass.append(char)
                i = pattern.index(after: i)
                while i < pattern.endIndex && pattern[i] != "]" {
                    charClass.append(pattern[i])
                    i = pattern.index(after: i)
                }
                if i < pattern.endIndex {
                    charClass.append("]")
                    i = pattern.index(after: i)
                }
                regex += charClass
            } else {
                let specialChars = "\\^$.|+(){}"
                if specialChars.contains(char) {
                    regex.append("\\")
                }
                regex.append(char)
                i = pattern.index(after: i)
            }
        }
        return regex
    }

}

/// Test helper that allows direct access to IgnoreMatcher internals
class DirectlyAccessibleIgnoreMatcher: IgnoreMatcher {
    /// Add a test pattern directly to the default patterns
    func addTestPattern(_ pattern: String) {
        // デバッグのためにパターンの追加をログ出力
        print("Adding pattern: \(pattern) to default patterns")
        defaultPatterns.append(pattern)
    }
    
    /// Get patterns for a specific directory
    func getTestPatterns(forDirectory dir: String) -> [String]? {
        return ignorePatterns[dir]
    }
}

/// Mock logger for testing
class MockLogger {
    private var logs: [String] = []
    
    func log(_ message: String) {
        logs.append(message)
    }
    
    func contains(_ substring: String) -> Bool {
        return logs.contains { log in
            log.contains(substring)
        }
    }
}
