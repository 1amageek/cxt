import Testing
import Foundation
@testable import cxt

@Suite("PathMatcher Tests")
struct PathMatcherTests {
    
    @Test("PathMatcher initializes properly")
    func testInitialization() {
        let matcher = PathMatcher()
        #expect(matcher is PathMatcher)
    }
    
    @Test("PathMatcher handles simple patterns")
    func testSimplePatterns() {
        let matcher = PathMatcher()
        
        // Simple file extension pattern
        #expect(matcher.matches(path: "file.txt", pattern: "*.txt"))
        #expect(matcher.matches(path: "path/to/file.txt", pattern: "*.txt"))
        #expect(!matcher.matches(path: "file.log", pattern: "*.txt"))
        
        // Simple filename pattern
        #expect(matcher.matches(path: "README.md", pattern: "README.md"))
        #expect(matcher.matches(path: "path/to/README.md", pattern: "README.md"))
        #expect(!matcher.matches(path: "README.txt", pattern: "README.md"))
    }
    
    @Test("PathMatcher handles directory patterns")
    func testDirectoryPatterns() {
        let matcher = PathMatcher()
        
        // Directory pattern with trailing slash
        #expect(matcher.matches(path: "node_modules/package.json", pattern: "node_modules/"))
        #expect(matcher.matches(path: "path/to/node_modules/package.json", pattern: "node_modules/"))
        #expect(!matcher.matches(path: "node_modulesplus/file.js", pattern: "node_modules/"))
        
        // Directory pattern without trailing slash (should be normalized)
        #expect(matcher.matches(path: "components/ui/button.tsx", pattern: "components/ui"))
        #expect(matcher.matches(path: "src/components/ui/button.tsx", pattern: "components/ui"))
        #expect(!matcher.matches(path: "components/utils/helpers.ts", pattern: "components/ui"))
    }
    
    @Test("PathMatcher handles wildcards correctly")
    func testWildcards() {
        let matcher = PathMatcher()
        
        // Single wildcard
        #expect(matcher.matches(path: "file.js", pattern: "*.js"))
        #expect(matcher.matches(path: "script.js", pattern: "*.js"))
        #expect(!matcher.matches(path: "file.jsx", pattern: "*.js"))
        
        // Question mark wildcard
        #expect(matcher.matches(path: "file1.js", pattern: "file?.js"))
        #expect(matcher.matches(path: "fileA.js", pattern: "file?.js"))
        #expect(!matcher.matches(path: "file10.js", pattern: "file?.js"))
        
        // Multiple wildcards
        #expect(matcher.matches(path: "test-file.js", pattern: "*-*.js"))
        #expect(!matcher.matches(path: "testfile.js", pattern: "*-*.js"))
    }
    
    @Test("PathMatcher handles character classes")
    func testCharacterClasses() {
        let matcher = PathMatcher()
        
        // Simple character class
        #expect(matcher.matches(path: "fileA.txt", pattern: "file[ABC].txt"))
        #expect(matcher.matches(path: "fileB.txt", pattern: "file[ABC].txt"))
        #expect(!matcher.matches(path: "fileD.txt", pattern: "file[ABC].txt"))
        
        // Character range
        #expect(matcher.matches(path: "file1.txt", pattern: "file[0-9].txt"))
        #expect(!matcher.matches(path: "fileA.txt", pattern: "file[0-9].txt"))
        
        // Negated character class (will use gitignore syntax with !)
        #expect(matcher.matches(path: "fileD.txt", pattern: "file[!ABC].txt"))
        #expect(!matcher.matches(path: "fileA.txt", pattern: "file[!ABC].txt"))
    }
    
    @Test("PathMatcher handles double-star patterns")
    func testDoubleStarPatterns() {
        let matcher = PathMatcher()
        
        // Leading double star
        #expect(matcher.matches(path: "src/components/Button.tsx", pattern: "**/components/*.tsx"))
        #expect(matcher.matches(path: "components/Button.tsx", pattern: "**/components/*.tsx"))
        #expect(!matcher.matches(path: "src/utils/helpers.ts", pattern: "**/components/*.tsx"))
        
        // Middle double star
        #expect(matcher.matches(path: "src/deep/path/file.txt", pattern: "src/**/file.txt"))
        #expect(matcher.matches(path: "src/file.txt", pattern: "src/**/file.txt"))
        #expect(!matcher.matches(path: "src/deep/path/other.txt", pattern: "src/**/file.txt"))
        
        // Double star for multiple directories
        #expect(matcher.matches(path: "src/components/ui/forms/Input.tsx", pattern: "src/components/**/Input.tsx"))
        #expect(!matcher.matches(path: "src/components/ui/forms/Button.tsx", pattern: "src/components/**/Input.tsx"))
    }
    
    @Test("PathMatcher handles complex patterns")
    func testComplexPatterns() {
        let matcher = PathMatcher()
        
        // Complex patterns with multiple wildcards and character classes
        #expect(matcher.matches(path: "src/components/ui/Button-large.tsx", pattern: "src/components/ui/*-[a-z]*.tsx"))
        #expect(!matcher.matches(path: "src/components/ui/Button_large.tsx", pattern: "src/components/ui/*-[a-z]*.tsx"))
        
        // Mix of wildcards and double-star
        #expect(matcher.matches(path: "test/components/deep/nested/Form.tsx", pattern: "test/**/[A-Z]*.tsx"))
        #expect(!matcher.matches(path: "test/components/deep/nested/utils.tsx", pattern: "test/**/[A-Z]*.tsx"))
    }
    
    @Test("PathMatcher normalizes patterns correctly")
    func testPatternNormalization() {
        let mockLogger = MockLogger()
        let matcher = PathMatcher(logger: mockLogger.log)
        
        let patterns = [
            "node_modules",            // No change needed
            "components/ui",           // Should add trailing slash
            "*.log",                   // No change needed
            "src/*/components",        // Should add trailing slash
            "build/"                   // No change needed (already has slash)
        ]
        
        let normalized = matcher.normalizePatterns(patterns)
        
        #expect(normalized.count == patterns.count)
        #expect(normalized[0] == "node_modules")       // Unchanged
        #expect(normalized[1] == "components/ui/")     // Trailing slash added
        #expect(normalized[2] == "*.log")              // Unchanged
        #expect(normalized[3] == "src/*/components/")  // Trailing slash added
        #expect(normalized[4] == "build/")             // Unchanged
        
        // Check that normalization was logged
        #expect(mockLogger.contains("Normalized pattern"))
        #expect(mockLogger.contains("components/ui"))
    }
    
    @Test("PathMatcher regex generation is correct")
    func testRegexGeneration() {
        let matcher = PathMatcher()
        
        // Test regex for simple file extension
        let extRegex = matcher.getRegexForPattern("*.js")
        #expect(extRegex.contains("\\.js$"))
        
        // Test regex for directory
        let dirRegex = matcher.getRegexForPattern("components/ui/")
        #expect(dirRegex.contains("^components/ui(?:/.*)?$"))
        
        // Test regex for pattern with wildcards
        let wildcardRegex = matcher.getRegexForPattern("src/**/*.tsx")
        #expect(wildcardRegex.contains("^src/.*/[^/]*\\.tsx(?:/.*)?$"))
    }
    
    @Test("PathMatcher handles edge cases")
    func testEdgeCases() {
        let matcher = PathMatcher()
        
        // Empty pattern
        #expect(!matcher.matches(path: "file.txt", pattern: ""))
        
        // Empty path
        #expect(!matcher.matches(path: "", pattern: "*.txt"))
        
        // Pattern with just a wildcard
        #expect(matcher.matches(path: "anything", pattern: "*"))
        #expect(matcher.matches(path: "file.txt", pattern: "*"))
        
        // Malformed character class
        #expect(!matcher.matches(path: "fileA.txt", pattern: "file[ABC.txt"))
        
        // Escaping special characters
        #expect(matcher.matches(path: "file(special).txt", pattern: "file(special).txt"))
        #expect(!matcher.matches(path: "fileXspecial.txt", pattern: "file(special).txt"))
    }
}
