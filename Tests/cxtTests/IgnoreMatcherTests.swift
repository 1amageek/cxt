import Testing
import Foundation
@testable import cxt

@Suite("IgnoreMatcher Tests")
struct IgnoreMatcherTests {
    
    @Test("IgnoreMatcher initializes properly")
    func testInitialization() {
        let matcher = IgnoreMatcher(
            basePath: "/test/path",
            respectIgnoreFiles: true,
            logger: { _ in },
            additionalPatterns: []
        )
        
        #expect(matcher.basePath == "/test/path/")
    }
    
    @Test("IgnoreMatcher loads default patterns")
    func testDefaultPatterns() {
        let mockLogger = MockLogger()
        let matcher = IgnoreMatcher(
            basePath: "/test/path",
            respectIgnoreFiles: true,
            logger: mockLogger.log,
            additionalPatterns: []
        )
        
        matcher.loadDefaultIgnorePatterns()
        let accessibleMatcher = DirectlyAccessibleIgnoreMatcher(
            basePath: "/test/path",
            respectIgnoreFiles: true,
            logger: mockLogger.log,
            additionalPatterns: []
        )
        accessibleMatcher.loadDefaultIgnorePatterns()
        
        // Check if common patterns are loaded
        let patterns = accessibleMatcher.getAllDefaultPatterns()
        #expect(patterns.contains("node_modules/"))
        #expect(patterns.contains(".git/"))
        #expect(patterns.contains(".DS_Store"))
        #expect(mockLogger.contains("Loaded"))
    }
    
    @Test("IgnoreMatcher normalizes additional patterns")
    func testAdditionalPatterns() {
        let mockLogger = MockLogger()
        let additionalPatterns = ["components/ui", "dist", "*.log"]
        
        let accessibleMatcher = DirectlyAccessibleIgnoreMatcher(
            basePath: "/test/path",
            respectIgnoreFiles: true,
            logger: mockLogger.log,
            additionalPatterns: additionalPatterns
        )
        accessibleMatcher.loadDefaultIgnorePatterns()
        
        let patterns = accessibleMatcher.getAllDefaultPatterns()
        #expect(patterns.contains("components/ui/"))
        #expect(patterns.contains("dist"))
        #expect(patterns.contains("*.log"))
        #expect(mockLogger.contains("Loaded"))
    }
    
    @Test("IgnoreMatcher should ignore node_modules directory")
    func testIgnoreNodeModules() {
        let mockLogger = MockLogger()
        let matcher = IgnoreMatcher(
            basePath: "/test/path",
            respectIgnoreFiles: true,
            logger: mockLogger.log,
            additionalPatterns: []
        )
        
        matcher.loadDefaultIgnorePatterns()
        
        // Add node_modules pattern manually to ensure it's there
        let accessibleMatcher = DirectlyAccessibleIgnoreMatcher(
            basePath: "/test/path",
            respectIgnoreFiles: true,
            logger: mockLogger.log,
            additionalPatterns: []
        )
        accessibleMatcher.loadDefaultIgnorePatterns()
        accessibleMatcher.addTestPattern("node_modules/")
        
        // Direct node_modules path
        #expect(accessibleMatcher.shouldIgnorePath("node_modules/package.json"))
        
        // Nested node_modules path
        #expect(accessibleMatcher.shouldIgnorePath("project/node_modules/package.json"))
        
        // Path with node_modules as part of a filename should not be ignored
        #expect(!accessibleMatcher.shouldIgnorePath("about-node_modules.txt"))
    }
    
    @Test("IgnoreMatcher should handle custom ignore patterns")
    func testCustomIgnorePatterns() {
        let mockLogger = MockLogger()
        let accessibleMatcher = DirectlyAccessibleIgnoreMatcher(
            basePath: "/test/path",
            respectIgnoreFiles: true,
            logger: mockLogger.log,
            additionalPatterns: ["components/ui", "*.log"]
        )
        
        accessibleMatcher.loadDefaultIgnorePatterns()
        
        // Direct components/ui path
        #expect(accessibleMatcher.shouldIgnorePath("components/ui/button.tsx"))
        
        // Nested components/ui path
        #expect(accessibleMatcher.shouldIgnorePath("src/components/ui/button.tsx"))
        
        // Log file pattern
        #expect(accessibleMatcher.shouldIgnorePath("logs/error.log"))
        #expect(accessibleMatcher.shouldIgnorePath("error.log"))
        
        // Non-matching paths
        #expect(!accessibleMatcher.shouldIgnorePath("components/utils/helper.ts"))
        #expect(!accessibleMatcher.shouldIgnorePath("ui/component/button.tsx"))
        #expect(!accessibleMatcher.shouldIgnorePath("error.txt"))
    }
    
    @Test("IgnoreMatcher should handle complex directory path patterns")
    func testComplexDirectoryPatterns() {
        let mockLogger = MockLogger()
        let accessibleMatcher = DirectlyAccessibleIgnoreMatcher(
            basePath: "/test/path",
            respectIgnoreFiles: true,
            logger: mockLogger.log,
            additionalPatterns: ["src/*/temp", "test/**/fixtures"]
        )
        
        accessibleMatcher.loadDefaultIgnorePatterns()
        
        // Add the specific patterns for this test
        accessibleMatcher.addTestPattern("src/*/temp/")
        accessibleMatcher.addTestPattern("test/**/fixtures/")
        
        // Print the patterns for debugging
        let patterns = accessibleMatcher.getAllDefaultPatterns()
        mockLogger.log("All patterns: \(patterns)")
        
        // Match src/anything/temp
        #expect(accessibleMatcher.shouldIgnorePath("src/project1/temp/file.txt"))
        #expect(accessibleMatcher.shouldIgnorePath("src/project2/temp/data.json"))
        
        // Test the double-star pattern directly using PathMatcher
        let pathMatcher = accessibleMatcher.testPathMatcher
        #expect(pathMatcher.matches(path: "test/fixtures/sample.txt", pattern: "test/**/fixtures/"))
        
        // Match test/fixtures or test/any/path/fixtures
        #expect(accessibleMatcher.shouldIgnorePath("test/fixtures/sample.txt"))
        #expect(accessibleMatcher.shouldIgnorePath("test/unit/fixtures/data.json"))
        #expect(accessibleMatcher.shouldIgnorePath("test/integration/api/fixtures/user.json"))
        
        // Non-matching paths
        #expect(!accessibleMatcher.shouldIgnorePath("src/temp/file.txt"))  // Missing middle component
        #expect(!accessibleMatcher.shouldIgnorePath("test/fixture/sample.txt"))  // Not exact match (fixtures vs fixture)
    }
    
    @Test("IgnoreMatcher should handle file extensions and wildcards")
    func testFileExtensionsAndWildcards() {
        let mockLogger = MockLogger()
        let accessibleMatcher = DirectlyAccessibleIgnoreMatcher(
            basePath: "/test/path",
            respectIgnoreFiles: true,
            logger: mockLogger.log,
            additionalPatterns: ["*.log", "temp-*", "data-?.json"]
        )
        
        accessibleMatcher.loadDefaultIgnorePatterns()
        
        // Add patterns directly
        accessibleMatcher.addTestPattern("*.log")
        accessibleMatcher.addTestPattern("temp-*")
        accessibleMatcher.addTestPattern("data-?.json")
        
        // Match *.log
        #expect(accessibleMatcher.shouldIgnorePath("error.log"))
        #expect(accessibleMatcher.shouldIgnorePath("logs/app.log"))
        
        // Match temp-*
        #expect(accessibleMatcher.shouldIgnorePath("temp-file.txt"))
        #expect(accessibleMatcher.shouldIgnorePath("src/temp-data.json"))
        
        // Match data-?.json (single character)
        #expect(accessibleMatcher.shouldIgnorePath("data-1.json"))
        #expect(accessibleMatcher.shouldIgnorePath("src/data-X.json"))
        
        // Non-matching paths
        #expect(!accessibleMatcher.shouldIgnorePath("error.txt"))
        #expect(!accessibleMatcher.shouldIgnorePath("temperature.txt"))
        #expect(!accessibleMatcher.shouldIgnorePath("data-10.json"))  // Two characters after hyphen
    }
    
    @Test("IgnoreMatcher should detect patterns in the middle of paths")
    func testMiddlePathPatterns() {
        let mockLogger = MockLogger()
        let accessibleMatcher = DirectlyAccessibleIgnoreMatcher(
            basePath: "/test/path",
            respectIgnoreFiles: true,
            logger: mockLogger.log,
            additionalPatterns: ["components/ui"]
        )
        
        accessibleMatcher.loadDefaultIgnorePatterns()
        
        // Add pattern directly
        accessibleMatcher.addTestPattern("components/ui/")
        
        // These should be ignored regardless of the path depth
        #expect(accessibleMatcher.shouldIgnorePath("components/ui/button.tsx"))
        #expect(accessibleMatcher.shouldIgnorePath("src/components/ui/dialog.tsx"))
        #expect(accessibleMatcher.shouldIgnorePath("project/src/components/ui/input.tsx"))
        #expect(accessibleMatcher.shouldIgnorePath("deep/nested/path/components/ui/checkbox.tsx"))
        
        // These should not be ignored
        #expect(!accessibleMatcher.shouldIgnorePath("ui/components/button.tsx"))  // Wrong order
        #expect(!accessibleMatcher.shouldIgnorePath("components/ui-kit/button.tsx"))  // Not exact match
        #expect(!accessibleMatcher.shouldIgnorePath("my-components/ui/button.tsx"))  // Not exact match
    }
    
    @Test("IgnoreMatcher should handle ignore files")
    func testIgnoreFiles() {
        // This test requires a mock file system or a temporary directory
        // Since we can't easily create actual files in a unit test, this is more
        // of an integration test placeholder
        
        // TODO: Implement a more robust test with a mock file system
        // For now, just ensure the method exists and doesn't crash
        let mockLogger = MockLogger()
        let matcher = IgnoreMatcher(
            basePath: FileManager.default.currentDirectoryPath,
            respectIgnoreFiles: true,
            logger: mockLogger.log,
            additionalPatterns: []
        )
        
        // This should not crash
        matcher.loadIgnoreFilesAt(FileManager.default.currentDirectoryPath)
    }
    
    @Test("IgnoreMatcher should handle real-world scenarios")
    func testRealWorldScenarios() {
        let mockLogger = MockLogger()
        let accessibleMatcher = DirectlyAccessibleIgnoreMatcher(
            basePath: "/project",
            respectIgnoreFiles: true,
            logger: mockLogger.log,
            additionalPatterns: [
                "node_modules",
                "dist",
                "build",
                "coverage",
                ".next",
                "components/ui",
                "*.log",
                "**/*.d.ts"
            ]
        )
        
        accessibleMatcher.loadDefaultIgnorePatterns()
        
        // Add patterns directly to ensure they're in the test
        accessibleMatcher.addTestPattern("node_modules/")
        accessibleMatcher.addTestPattern("dist/")
        accessibleMatcher.addTestPattern("build/")
        accessibleMatcher.addTestPattern("coverage/")
        accessibleMatcher.addTestPattern(".next/")
        accessibleMatcher.addTestPattern("components/ui/")
        accessibleMatcher.addTestPattern("*.log")
        accessibleMatcher.addTestPattern("**/*.d.ts")
        
        // Print patterns for debugging
        mockLogger.log("All patterns: \(accessibleMatcher.getAllDefaultPatterns())")
        
        // Common web project paths to ignore
        #expect(accessibleMatcher.shouldIgnorePath("node_modules/react/index.js"))
        #expect(accessibleMatcher.shouldIgnorePath("src/components/ui/button.tsx"))
        #expect(accessibleMatcher.shouldIgnorePath("dist/main.js"))
        #expect(accessibleMatcher.shouldIgnorePath("build/static/js/app.js"))
        #expect(accessibleMatcher.shouldIgnorePath("coverage/lcov-report/index.html"))
        #expect(accessibleMatcher.shouldIgnorePath(".next/server/pages/index.js"))
        #expect(accessibleMatcher.shouldIgnorePath("logs/error.log"))
        #expect(accessibleMatcher.shouldIgnorePath("src/types/user.d.ts"))
        
        // Paths that should not be ignored
        #expect(!accessibleMatcher.shouldIgnorePath("src/components/layout/Header.tsx"))
        #expect(!accessibleMatcher.shouldIgnorePath("src/pages/index.tsx"))
        #expect(!accessibleMatcher.shouldIgnorePath("README.md"))
        #expect(!accessibleMatcher.shouldIgnorePath("src/types/user.ts"))  // Not a .d.ts file
    }
    
    @Test("IgnoreMatcher should handle absolute and relative paths correctly")
    func testAbsoluteAndRelativePaths() {
        let mockLogger = MockLogger()
        let basePath = "/project/src"
        let accessibleMatcher = DirectlyAccessibleIgnoreMatcher(
            basePath: basePath,
            respectIgnoreFiles: true,
            logger: mockLogger.log,
            additionalPatterns: ["components/ui", "utils/temp"]
        )
        
        accessibleMatcher.loadDefaultIgnorePatterns()
        
        // Add patterns directly
        accessibleMatcher.addTestPattern("components/ui/")
        accessibleMatcher.addTestPattern("utils/temp/")
        
        // Relative paths
        #expect(accessibleMatcher.shouldIgnorePath("components/ui/button.tsx"))
        #expect(accessibleMatcher.shouldIgnorePath("utils/temp/helper.ts"))
        
        // Different base path should not affect pattern matching
        let accessibleMatcher2 = DirectlyAccessibleIgnoreMatcher(
            basePath: "/different/base",
            respectIgnoreFiles: true,
            logger: mockLogger.log,
            additionalPatterns: ["components/ui", "utils/temp"]
        )
        
        accessibleMatcher2.loadDefaultIgnorePatterns()
        accessibleMatcher2.addTestPattern("components/ui/")
        accessibleMatcher2.addTestPattern("utils/temp/")
        
        #expect(accessibleMatcher2.shouldIgnorePath("components/ui/button.tsx"))
        #expect(accessibleMatcher2.shouldIgnorePath("src/components/ui/button.tsx"))
        #expect(accessibleMatcher2.shouldIgnorePath("project/src/components/ui/button.tsx"))
    }
}
