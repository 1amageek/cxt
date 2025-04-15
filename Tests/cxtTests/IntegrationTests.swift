import Testing
import Foundation
@testable import cxt

@Suite("Integration Tests")
struct IntegrationTests {
    
    @Test("FileProcessor should respect ignore patterns correctly")
    func testFileProcessorWithIgnorePatterns() {
        let mockLogger = MockLogger()
        
        // Create a file processor with ignore patterns
        let fileProcessor = FileProcessor(
            logger: mockLogger.log,
            respectIgnoreFiles: true,
            additionalPatterns: ["components/ui", "node_modules"]
        )
        
        // Mock files for testing
        let files: [FileInfo] = [
            FileInfo(url: URL(fileURLWithPath: "/test/src/components/layout/Header.tsx"), relativePath: "src/components/layout/Header.tsx"),
            FileInfo(url: URL(fileURLWithPath: "/test/src/components/ui/Button.tsx"), relativePath: "src/components/ui/Button.tsx"),
            FileInfo(url: URL(fileURLWithPath: "/test/src/components/ui/Dialog.tsx"), relativePath: "src/components/ui/Dialog.tsx"),
            FileInfo(url: URL(fileURLWithPath: "/test/node_modules/package.json"), relativePath: "node_modules/package.json"),
            FileInfo(url: URL(fileURLWithPath: "/test/src/app/page.tsx"), relativePath: "src/app/page.tsx")
        ]
        
        // Create an IgnoreMatcher with the same settings
        let ignoreMatcher = IgnoreMatcher(
            basePath: "/test",
            respectIgnoreFiles: true,
            logger: mockLogger.log,
            additionalPatterns: ["components/ui", "node_modules"]
        )
        
        ignoreMatcher.loadDefaultIgnorePatterns()
        
        // Test that paths are correctly identified for ignoring
        #expect(ignoreMatcher.shouldIgnorePath("src/components/ui/Button.tsx"))
        #expect(ignoreMatcher.shouldIgnorePath("node_modules/package.json"))
        #expect(!ignoreMatcher.shouldIgnorePath("src/app/page.tsx"))
        
        // Log patterns for debugging
        mockLogger.log("Ignore patterns loaded")
        
        // Clear the mock logger to start fresh
        mockLogger.clear()
        
        // Use FileProcessor's extractRelevantFiles to filter out ignored files
        let paths = ["src/app/page.tsx", "src/components/layout/Header.tsx"]
        let relevantFiles = fileProcessor.extractRelevantFiles(
            fromPaths: paths,
            basePath: "/test",
            allFiles: files
        )
        
        // Check the result - only non-ignored files should be included
        #expect(relevantFiles.count == 2)
        #expect(relevantFiles.contains { $0.relativePath == "src/app/page.tsx" })
        #expect(relevantFiles.contains { $0.relativePath == "src/components/layout/Header.tsx" })
        #expect(!relevantFiles.contains { $0.relativePath == "src/components/ui/Button.tsx" })
        #expect(!relevantFiles.contains { $0.relativePath == "node_modules/package.json" })
    }
    
    @Test("Full command line simulation test")
    func testCommandLineSimulation() {
        let mockLogger = MockLogger()
        
        // Create mock files
        let mockFiles: [FileInfo] = [
            FileInfo(url: URL(fileURLWithPath: "/project/src/components/layout/Header.tsx"), relativePath: "src/components/layout/Header.tsx"),
            FileInfo(url: URL(fileURLWithPath: "/project/src/components/ui/Button.tsx"), relativePath: "src/components/ui/Button.tsx"),
            FileInfo(url: URL(fileURLWithPath: "/project/src/components/ui/Dialog.tsx"), relativePath: "src/components/ui/Dialog.tsx"),
            FileInfo(url: URL(fileURLWithPath: "/project/node_modules/package.json"), relativePath: "node_modules/package.json"),
            FileInfo(url: URL(fileURLWithPath: "/project/src/app/page.tsx"), relativePath: "src/app/page.tsx"),
            FileInfo(url: URL(fileURLWithPath: "/project/src/lib/utils.ts"), relativePath: "src/lib/utils.ts")
        ]
        
        // Create ignore matcher for simulation
        let ignoreMatcher = IgnoreMatcher(
            basePath: "/project",
            respectIgnoreFiles: true,
            logger: mockLogger.log,
            additionalPatterns: ["components/ui", "node_modules"]
        )
        
        ignoreMatcher.loadDefaultIgnorePatterns()
        
        // Filter files that should not be ignored
        let filteredFiles = mockFiles.filter { file in
            return !ignoreMatcher.shouldIgnorePath(file.relativePath)
        }
        
        // Check the results
        #expect(filteredFiles.count == 3) // Should only include non-ignored files
        #expect(filteredFiles.contains { $0.relativePath == "src/components/layout/Header.tsx" })
        #expect(filteredFiles.contains { $0.relativePath == "src/app/page.tsx" })
        #expect(filteredFiles.contains { $0.relativePath == "src/lib/utils.ts" })
        #expect(!filteredFiles.contains { $0.relativePath == "src/components/ui/Button.tsx" })
        #expect(!filteredFiles.contains { $0.relativePath == "src/components/ui/Dialog.tsx" })
        #expect(!filteredFiles.contains { $0.relativePath == "node_modules/package.json" })
        
        // Ensure we get the correct logs
        #expect(mockLogger.contains("Loaded"))
    }
    
    @Test("Context agent path filtering")
    func testContextAgentPathFiltering() {
        let mockLogger = MockLogger()
        
        // Create mock files
        let mockFiles: [FileInfo] = [
            FileInfo(url: URL(fileURLWithPath: "/project/src/components/layout/Header.tsx"), relativePath: "src/components/layout/Header.tsx"),
            FileInfo(url: URL(fileURLWithPath: "/project/src/components/ui/Button.tsx"), relativePath: "src/components/ui/Button.tsx"),
            FileInfo(url: URL(fileURLWithPath: "/project/src/components/ui/Dialog.tsx"), relativePath: "src/components/ui/Dialog.tsx"),
            FileInfo(url: URL(fileURLWithPath: "/project/src/app/page.tsx"), relativePath: "src/app/page.tsx"),
            FileInfo(url: URL(fileURLWithPath: "/project/src/lib/utils.ts"), relativePath: "src/lib/utils.ts")
        ]
        
        // Create file processor
        let fileProcessor = FileProcessor(
            logger: mockLogger.log,
            respectIgnoreFiles: true,
            additionalPatterns: ["components/ui"]
        )
        
        // Simulate context agent returning paths
        let agentPaths = ["src/components/layout/Header.tsx", "src/app/page.tsx"]
        
        // Extract relevant files
        let relevantFiles = fileProcessor.extractRelevantFiles(
            fromPaths: agentPaths,
            basePath: "/project",
            allFiles: mockFiles
        )
        
        // Verify result
        #expect(relevantFiles.count == 2)
        #expect(relevantFiles.contains { $0.relativePath == "src/components/layout/Header.tsx" })
        #expect(relevantFiles.contains { $0.relativePath == "src/app/page.tsx" })
        #expect(!relevantFiles.contains { $0.relativePath == "src/components/ui/Button.tsx" })
        #expect(!relevantFiles.contains { $0.relativePath == "src/lib/utils.ts" })
    }
    
    @Test("Content generation maintains integrity")
    func testContentGeneration() {
        let mockLogger = MockLogger()
        
        // Create a helper function to generate test content
        func generateTestContent(files: [FileInfo], basePath: String, extensions: [String]) -> String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let currentDate = dateFormatter.string(from: Date())
            
            var content = """
            ---
            created_at: \(currentDate)
            extensions: [\(extensions.map { "." + $0 }.joined(separator: ", "))]
            base_path: \(basePath)
            ---
            
            """
            
            // Add mock content for each file
            for file in files {
                content += """
                
                # \(file.relativePath)
                
                ```\(file.url.pathExtension)
                // Mock content for \(file.relativePath)
                ```
                
                """
            }
            
            return content
        }
        
        // Create mock files
        let mockFiles: [FileInfo] = [
            FileInfo(url: URL(fileURLWithPath: "/project/src/app/page.tsx"), relativePath: "src/app/page.tsx"),
            FileInfo(url: URL(fileURLWithPath: "/project/src/lib/utils.ts"), relativePath: "src/lib/utils.ts")
        ]
        
        // Generate test content
        let content = generateTestContent(
            files: mockFiles,
            basePath: "/project",
            extensions: ["ts", "tsx"]
        )
        
        // Verify basic structure
        #expect(content.contains("---"))  // Has frontmatter
        #expect(content.contains("created_at:"))  // Has timestamp
        #expect(content.contains("extensions: [.ts, .tsx]"))  // Has extensions
        #expect(content.contains("base_path: /project"))  // Has base path
        
        // Should have file headings
        #expect(content.contains("# src/app/page.tsx"))
        #expect(content.contains("# src/lib/utils.ts"))
        
        // Should have mock content
        #expect(content.contains("// Mock content for src/app/page.tsx"))
        #expect(content.contains("// Mock content for src/lib/utils.ts"))
    }
}
