import Foundation
@testable import cxt

/// Test helper that allows direct access to IgnoreMatcher internals
class DirectlyAccessibleIgnoreMatcher: IgnoreMatcher {
    /// The path matcher instance
    var testPathMatcher: PathMatcher {
        return PathMatcher(logger: { print($0) })
    }
    
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
    
    /// Get all default patterns
    func getAllDefaultPatterns() -> [String] {
        return defaultPatterns
    }
    
    /// Test match directly
    func testMatch(path: String, pattern: String) -> Bool {
        return testPathMatcher.matches(path: path, pattern: pattern)
    }
    
    /// Compatibility method for old tests that used matchPatternSimple
    func matchPatternSimple(pattern: String, path: String) -> Bool {
        return testPathMatcher.matches(path: path, pattern: pattern)
    }
    
    /// Get regex for pattern
    func getRegexForPattern(_ pattern: String) -> String {
        return testPathMatcher.getRegexForPattern(pattern)
    }
}
