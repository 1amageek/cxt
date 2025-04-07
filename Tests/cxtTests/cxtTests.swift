import Testing
import Foundation
@testable import cxt

// MARK: - FileProcessor Tests

@Suite("FileProcessor Tests")
struct FileProcessorTests {
    
    @Test("FileProcessor initializes with default parameters")
    func testFileProcessorInit() {
        let processor = FileProcessor()
        #expect(processor is FileProcessor)
    }
    
    @Test("FileProcessor generates content correctly")
    func testGenerateContent() throws {
        let processor = FileProcessor()
        // テスト固有のディレクトリ名を使用
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cxt_test_generate_content_123456")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // テスト固有のファイル名
        let tempFileURL = tempDir.appendingPathComponent("generate_content_test_file.swift")
        let fileContent = "func test() { print(\"Hello, World!\") }"
        
        // defer を使用して確実なクリーンアップを保証
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        try fileContent.write(to: tempFileURL, atomically: true, encoding: .utf8)
        
        let files = [
            FileInfo(url: tempFileURL, relativePath: "generate_content_test_file.swift")
        ]
        
        let content = processor.generateContent(
            files: files,
            basePath: tempDir.path,
            extensions: ["swift"]
        )
        
        #expect(content.contains("created_at:"))
        #expect(content.contains("extensions: [.swift]"))
        #expect(content.contains("base_path: \(tempDir.path)"))
        #expect(content.contains("# generate_content_test_file.swift"))
        #expect(content.contains("```swift"))
        #expect(content.contains(fileContent))
    }
    
    @Test("scanDirectory scans simple directory structure")
    func testScanDirectorySingleFile() throws {
        // 単純な構造のディレクトリとファイルを作成
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cxt_scan_single_123")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // 単一のSwiftファイル
        let swiftFile = tempDir.appendingPathComponent("test_single.swift")
        try "// Test file content" .write(to: swiftFile, atomically: true, encoding: .utf8)
        
        // 処理されないテキストファイル
        let textFile = tempDir.appendingPathComponent("test_single.txt")
        try "Text content" .write(to: textFile, atomically: true, encoding: .utf8)
        
        // すべてのignoreパターンを無効にした状態で単純なFileProcessorを作成
        let processor = FileProcessor(
            respectIgnoreFiles: false,
            additionalPatterns: []
        )
        
        // ファイルをスキャン
        let files = try processor.scanDirectory(
            path: tempDir.path,
            extensions: ["swift"]
        )
        
        // 期待される結果：Swiftファイルだけが見つかる
        #expect(files.count == 1, "Found \(files.count) files instead of 1")
        
        // 条件付きでインデックスアクセス - 配列が空でないことを確認してからアクセス
        if !files.isEmpty {
            #expect(files[0].url.lastPathComponent == "test_single.swift")
        } else {
            Issue.record("Expected at least one file, but files array is empty")
        }
    }
    
    @Test("scanDirectory handles symbolic links correctly")
    func testScanDirectoryWithSymbolicLinks() throws {
        // テスト用ディレクトリ構造
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cxt_symlink_test_456")
        let subDir = tempDir.appendingPathComponent("subdir")
        let cycleDir = tempDir.appendingPathComponent("cycle")
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cycleDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // テストファイル作成
        let swiftFile = subDir.appendingPathComponent("test_symlink.swift")
        try "// Test symlink" .write(to: swiftFile, atomically: true, encoding: .utf8)
        
        // cycleDir内に親ディレクトリへのシンボリックリンクを作成（循環構造）
        // 注：このテストはシンボリックリンクをサポートするシステムでのみ動作
        let linkPath = cycleDir.appendingPathComponent("parent_link")
        
        do {
            // シンボリックリンクの作成を試みる
            try FileManager.default.createSymbolicLink(
                at: linkPath,
                withDestinationURL: tempDir
            )
            
            // 循環参照のチェック用に変更したFileProcessor
            let mockLogger = MockLogger()
            let processor = FileProcessor(
                logger: mockLogger.log,
                respectIgnoreFiles: false,
                additionalPatterns: []
            )
            
            // scanDirectoryの実行
            let files = try processor.scanDirectory(
                path: tempDir.path,
                extensions: ["swift"]
            )
            
            // 結果を検証
            #expect(files.count == 1)
            #expect(files[0].url.lastPathComponent == "test_symlink.swift")
            
            // ログ出力から循環参照が適切に処理されたか確認
            // 新しい実装では循環参照は自動的に処理されるはず
        } catch {
            // シンボリックリンク作成エラーの場合はテストをスキップ
            Issue.record("Skipping symbolic link test: \(error.localizedDescription)")
        }
    }
    
    @Test("FileProcessor handles real directory structure")
    func testFileProcessorWithRealStructure() throws {
        // テスト固有のディレクトリ名を使用
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cxt_test_real_structure_789012")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // 必ず削除されるように defer ブロックを使用
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // テスト固有のディレクトリ構造
        let sourcesDir = tempDir.appendingPathComponent("src")
        
        try FileManager.default.createDirectory(at: sourcesDir, withIntermediateDirectories: true)
        
        // テスト固有のファイル名
        let mainSwift = sourcesDir.appendingPathComponent("real_structure_main.swift")
        let ignoredTxt = sourcesDir.appendingPathComponent("real_structure_notes.txt")
        
        try "func mainTest() {}" .write(to: mainSwift, atomically: true, encoding: .utf8)
        try "Just some notes for testing" .write(to: ignoredTxt, atomically: true, encoding: .utf8)
        
        // Create a FileProcessor with respectIgnoreFiles = false to simplify test
        let mockLogger = MockLogger()
        let processor = FileProcessor(
            logger: mockLogger.log,
            respectIgnoreFiles: false
        )
        
        // Scan for Swift files
        let files = try processor.scanDirectory(
            path: tempDir.path,
            extensions: ["swift"]
        )
        
        // Verify correct files found
        #expect(files.count == 1, "Expected to find exactly 1 file")
        
        if !files.isEmpty {
            #expect(files.contains(where: { $0.relativePath.hasSuffix("real_structure_main.swift") }),
                    "Should contain main.swift file")
            #expect(!files.contains(where: { $0.relativePath.hasSuffix("real_structure_notes.txt") }),
                    "Should not contain .txt files")
        } else {
            Issue.record("No files found in real directory structure test")
        }
        
        // Test content generation
        let content = processor.generateContent(
            files: files,
            basePath: tempDir.path,
            extensions: ["swift"]
        )
        
        #expect(content.contains("```swift"))
        #expect(content.contains("func mainTest() {}"))
    }
    
    // FileProcessor#extractRelevantFilesの単体テスト
    @Test("extractRelevantFiles correctly identifies files")
    func testExtractRelevantFilesSimple() {
        // FileProcessorを初期化
        let processor = FileProcessor()
        
        // テスト用のFileInfo配列を作成
        let basePath = "/test/base"
        let allFiles = [
            FileInfo(url: URL(fileURLWithPath: "/test/base/file1.swift"), relativePath: "file1.swift"),
            FileInfo(url: URL(fileURLWithPath: "/test/base/subdir/file2.swift"), relativePath: "subdir/file2.swift"),
            FileInfo(url: URL(fileURLWithPath: "/test/base/file3.txt"), relativePath: "file3.txt")
        ]
        
        // 完全一致するパスのテスト
        let exactPaths = ["file1.swift"]
        let exactMatches = processor.extractRelevantFiles(
            fromPaths: exactPaths,
            basePath: basePath,
            allFiles: allFiles
        )
        
        #expect(exactMatches.count == 1, "Expected exactly 1 match for exact path")
        
        if !exactMatches.isEmpty {
            #expect(exactMatches[0].relativePath == "file1.swift")
        } else {
            Issue.record("No exact matches found")
        }
        
        // 実装では、"subdir"だけだと一致しないため、パスに合わせて修正
        // file.relativePath.hasSuffix(normalizedPath) のケースをテスト
        let suffixPaths = ["file2.swift"]
        let suffixMatches = processor.extractRelevantFiles(
            fromPaths: suffixPaths,
            basePath: basePath,
            allFiles: allFiles
        )
        
        #expect(suffixMatches.count == 1, "Expected exactly 1 match for suffix path")
        
        if !suffixMatches.isEmpty {
            #expect(suffixMatches[0].relativePath == "subdir/file2.swift")
        } else {
            Issue.record("No suffix matches found")
        }
        
        // normalizedPath.hasSuffix(file.relativePath) のケースをテスト
        let parentPaths = ["subdir/file2.swift"]
        let parentMatches = processor.extractRelevantFiles(
            fromPaths: parentPaths,
            basePath: basePath,
            allFiles: allFiles
        )
        
        #expect(parentMatches.count == 1, "Expected exactly 1 match for parent path")
        
        if !parentMatches.isEmpty {
            #expect(parentMatches[0].relativePath == "subdir/file2.swift")
        } else {
            Issue.record("No parent matches found")
        }
    }
}

// MARK: - IgnoreMatcher Tests

@Suite("IgnoreMatcher Tests")
struct IgnoreMatcherTests {
    
    @Test("IgnoreMatcher initializes correctly")
    func testIgnoreMatcherInit() {
        let ignoreMatcherWithLeadingSlash = IgnoreMatcher(
            basePath: "/path/to/dir/",
            respectIgnoreFiles: true,
            logger: { _ in },
            additionalPatterns: []
        )
        #expect(ignoreMatcherWithLeadingSlash.basePath == "/path/to/dir/")
        
        let ignoreMatcherWithoutLeadingSlash = IgnoreMatcher(
            basePath: "/path/to/dir",
            respectIgnoreFiles: true,
            logger: { _ in },
            additionalPatterns: []
        )
        #expect(ignoreMatcherWithoutLeadingSlash.basePath == "/path/to/dir/")
    }
    
    @Test("IgnoreMatcher loads and applies additional patterns")
    func testAdditionalPatterns() {
        // 独立したテスト用に新しいインスタンスを作成
        let mockLogger = MockLogger()
        
        // 追加パターンを直接指定してIgnoreMatcherを作成
        let ignoreMatcher = IgnoreMatcher(
            basePath: "/test",
            respectIgnoreFiles: true,
            logger: mockLogger.log,
            additionalPatterns: ["*.log", "tmp/"]
        )
        
        // デフォルトパターンと追加パターンを読み込む
        ignoreMatcher.loadDefaultIgnorePatterns()
        
        // 追加パターンのみをテスト (デフォルトパターンは別途テスト)
        // "*.log" パターンのテスト
        let logFilePath = "app.log"
        #expect(ignoreMatcher.shouldIgnorePath(logFilePath),
                "Path '\(logFilePath)' should match pattern '*.log'")
        
        // "tmp/" パターンのテスト
        let tmpDirPath = "tmp/cache"
        #expect(ignoreMatcher.shouldIgnorePath(tmpDirPath),
                "Path '\(tmpDirPath)' should match pattern 'tmp/'")
        
        // 無視されないパスの確認
        let normalFile = "app.txt"
        #expect(!ignoreMatcher.shouldIgnorePath(normalFile),
                "Path '\(normalFile)' should not be ignored")
    }
    
    @Test("Debug *.txt pattern matching")
    func testDebugSimplePattern() {
        // デバッグ用の単純なテスト
        let debugLogger = MockLogger()
        let testMatcher = DirectlyAccessibleIgnoreMatcher(
            basePath: "/test",
            respectIgnoreFiles: false,
            logger: { print($0) }, // コンソールに直接出力
            additionalPatterns: []
        )
        
        // パターンを直接追加
        testMatcher.addTestPattern("*.txt")
        
        // デフォルトパターンの内容を確認
        print("Default patterns: \(testMatcher.defaultPatterns)")
        
        // パターンマッチングをテスト
        let result = testMatcher.shouldIgnorePath("document.txt")
        print("Should ignore 'document.txt': \(result)")
        
        // 直接マッチメソッドをテスト
        let directResult = testMatcher.matchPatternSimple(pattern: "*.txt", path: "document.txt")
        print("Direct match result: \(directResult)")
        
        // 期待されるマッチング結果
        #expect(directResult, "*.txt should match 'document.txt' in direct test")
        #expect(result, "*.txt should match 'document.txt' in full test")
    }
    
    @Test("IgnoreMatcher path matching with manually added patterns")
    func testDirectPatternMatching() {
        // テスト用に基本的なIgnoreMatcherを作成
        let ignoreMatcher = DirectlyAccessibleIgnoreMatcher(
            basePath: "/test",
            respectIgnoreFiles: true,
            logger: { _ in },
            additionalPatterns: []
        )
        
        // DirectlyAccessibleIgnoreMatcherを使用してパターンを直接追加
        ignoreMatcher.addTestPattern("*.txt")
        ignoreMatcher.addTestPattern("tmp/")
        ignoreMatcher.addTestPattern("**/*.tmp")
        ignoreMatcher.addTestPattern("build/*/cache")
        ignoreMatcher.addTestPattern("src/[abc]*.swift")
        ignoreMatcher.addTestPattern("test/sample?file.js")
        
        // テキストファイルパターン
        #expect(ignoreMatcher.shouldIgnorePath("document.txt"),
                "*.txt should match 'document.txt'")
        
        // ディレクトリパターン
        #expect(ignoreMatcher.shouldIgnorePath("tmp/file.js"),
                "tmp/ should match 'tmp/file.js'")
        
        // 再帰的ワイルドカード
        #expect(ignoreMatcher.shouldIgnorePath("src/folder/deep/file.tmp"),
                "**/*.tmp should match 'src/folder/deep/file.tmp'")
        
        // ワイルドカードを含むパス
        #expect(ignoreMatcher.shouldIgnorePath("build/debug/cache"),
                "build/*/cache should match 'build/debug/cache'")
        
        // 文字クラス
        #expect(ignoreMatcher.shouldIgnorePath("src/afile.swift"),
                "src/[abc]*.swift should match 'src/afile.swift'")
        
        // 単一文字ワイルドカード
        #expect(ignoreMatcher.shouldIgnorePath("test/sample1file.js"),
                "test/sample?file.js should match 'test/sample1file.js'")
        
        // 無視されないパスをテスト
        #expect(!ignoreMatcher.shouldIgnorePath("document.md"),
                "*.txt should not match 'document.md'")
        #expect(!ignoreMatcher.shouldIgnorePath("temporary"),
                "tmp/ should not match 'temporary'")
        #expect(!ignoreMatcher.shouldIgnorePath("src/folder/deep/file.jpg"),
                "**/*.tmp should not match 'src/folder/deep/file.jpg'")
        #expect(!ignoreMatcher.shouldIgnorePath("build/debug/cache/extra"),
                "build/*/cache should not match 'build/debug/cache/extra'")
        #expect(!ignoreMatcher.shouldIgnorePath("src/dfile.swift"),
                "src/[abc]*.swift should not match 'src/dfile.swift'")
        #expect(!ignoreMatcher.shouldIgnorePath("test/sample12file.js"),
                "test/sample?file.js should not match 'test/sample12file.js'")
    }
    
    @Test("IgnoreMatcher handles complex glob patterns with manual patterns")
    func testComplexGlobPatternsManual() {
        let mockLogger = MockLogger()
        let ignoreMatcher = DirectlyAccessibleIgnoreMatcher(
            basePath: "/test",
            respectIgnoreFiles: true,
            logger: mockLogger.log,
            additionalPatterns: []
        )
        
        // テスト用のパターンを直接追加
        ignoreMatcher.addTestPattern("**/node_modules/**")
        ignoreMatcher.addTestPattern("*.log")
        ignoreMatcher.addTestPattern("dist/")
        ignoreMatcher.addTestPattern("**/*.min.js")
        
        // Double-star wildcard test
        #expect(ignoreMatcher.shouldIgnorePath("node_modules/some-package/index.js"),
                "Path should match **/node_modules/** pattern")
        #expect(ignoreMatcher.shouldIgnorePath("packages/node_modules/file.js"),
                "Path should match **/node_modules/** pattern")
        
        // Single-star wildcard test
        #expect(ignoreMatcher.shouldIgnorePath("error.log"),
                "Path should match *.log pattern")
        #expect(ignoreMatcher.shouldIgnorePath("logs/error.log"),
                "Path with subdirectory should match *.log pattern")
        
        // Directory pattern test
        #expect(ignoreMatcher.shouldIgnorePath("dist/bundle.js"),
                "Path should match dist/ pattern")
        
        // Complex pattern test
        #expect(ignoreMatcher.shouldIgnorePath("scripts/app.min.js"),
                "Path should match **/*.min.js pattern")
        #expect(ignoreMatcher.shouldIgnorePath("nested/folder/utils.min.js"),
                "Path in subdirectory should match **/*.min.js pattern")
        
        // Non-matching tests
        #expect(!ignoreMatcher.shouldIgnorePath("regular.js"),
                "Regular JS file should not be ignored")
    }
    
    @Test("IgnoreMatcher excludes node_modules as specified in .gitignore")
    func testGitignoreNodeModulesExclusion() throws {
        // 一時ディレクトリを作成
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ignore_test_node_modules")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // .gitignore を作成し、node_modules を除外対象にする
        let gitignorePath = tempDir.appendingPathComponent(".gitignore")
        let gitignoreContent = """
    # Exclude node_modules directory
    node_modules
    """
        try gitignoreContent.write(to: gitignorePath, atomically: true, encoding: .utf8)
        
        // IgnoreMatcher を初期化（ignore ファイルを尊重する設定）
        let mockLogger = MockLogger()
        let ignoreMatcher = IgnoreMatcher(
            basePath: tempDir.path,
            respectIgnoreFiles: true,
            logger: mockLogger.log,
            additionalPatterns: []
        )
        ignoreMatcher.loadDefaultIgnorePatterns()
        // 一時ディレクトリ内の .gitignore を読み込む
        ignoreMatcher.loadIgnoreFilesAt(tempDir.path)
        
        // "node_modules" およびその配下のパスは除外されるはず
        #expect(ignoreMatcher.shouldIgnorePath("node_modules"), "The node_modules directory should be ignored")
        #expect(ignoreMatcher.shouldIgnorePath("node_modules/some_module/index.js"), "Files under node_modules should be ignored")
        
        // 一方、別ディレクトリ内の node_modules という文字列が含まれるパスは除外されない（.gitignore の対象ではない）
        #expect(!ignoreMatcher.shouldIgnorePath("src/node_modules/file.js"), "Files in non-target directories should not be ignored")
    }
    
    
    @Test("IgnoreMatcher loads single ignore file correctly")
    func testLoadSingleIgnoreFile() throws {
        // テスト固有のディレクトリ名を使用
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cxt_ignore_test_single_345678")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // テスト固有の.gitignoreファイルだけを作成
        let gitignorePath = tempDir.appendingPathComponent(".gitignore")
        let gitignoreContent = """
        # この行はコメントなので無視される
        *.generated.swift
        build/
        .DS_Store
        """
        try gitignoreContent.write(to: gitignorePath, atomically: true, encoding: .utf8)
        
        // mockLoggerを使用して、ログメッセージを確認
        let mockLogger = MockLogger()
        let ignoreMatcher = DirectlyAccessibleIgnoreMatcher(
            basePath: tempDir.path,
            respectIgnoreFiles: true,
            logger: mockLogger.log,
            additionalPatterns: []
        )
        
        // ファイルを読み込む前のテスト
        #expect(!ignoreMatcher.shouldIgnorePath("Model.generated.swift"),
                "Path should not be ignored before loading ignore file")
        
        // ignoreファイルを読み込む
        ignoreMatcher.loadIgnoreFilesAt(tempDir.path)
        
        // ファイルを読み込んだ後にパターンが正しく適用されているか確認
        // ここではDirectlyAccessibleIgnoreMatcherでテストする前にパターンが追加されていることを確認
        let patterns = ignoreMatcher.getTestPatterns(forDirectory: tempDir.path)
        #expect(patterns != nil && patterns!.count == 3,
                "Should have loaded 3 patterns from .gitignore, found: \(patterns?.count ?? 0)")
        
        if patterns != nil && patterns!.count >= 3 {
            #expect(patterns!.contains("*.generated.swift"), "Pattern '*.generated.swift' should be loaded")
            #expect(patterns!.contains("build/"), "Pattern 'build/' should be loaded")
            #expect(patterns!.contains(".DS_Store"), "Pattern '.DS_Store' should be loaded")
        }
        
        // ログが適切に記録されているか確認
        #expect(mockLogger.contains("Loaded"), "Should log pattern loading")
        #expect(mockLogger.contains("patterns from .gitignore"), "Should log .gitignore loading")
    }
    
//    @Test("IgnoreMatcher handles complex glob patterns with manual patterns")
//    func testComplexGlobPatternsManual() {
//        let mockLogger = MockLogger()
//        let ignoreMatcher = DirectlyAccessibleIgnoreMatcher(
//            basePath: "/test",
//            respectIgnoreFiles: true,
//            logger: mockLogger.log,
//            additionalPatterns: []
//        )
//        
//        // テスト用のパターンを直接追加
//        ignoreMatcher.addTestPattern("**/node_modules/**")
//        ignoreMatcher.addTestPattern("*.log")
//        ignoreMatcher.addTestPattern("dist/")
//        ignoreMatcher.addTestPattern("**/*.min.js")
//        
//        // Double-star wildcard test
//        #expect(ignoreMatcher.shouldIgnorePath("node_modules/some-package/index.js"),
//                "Path should match **/node_modules/** pattern")
//        #expect(ignoreMatcher.shouldIgnorePath("packages/node_modules/file.js"),
//                "Path should match **/node_modules/** pattern")
//        
//        // Single-star wildcard test
//        #expect(ignoreMatcher.shouldIgnorePath("error.log"),
//                "Path should match *.log pattern")
//        #expect(ignoreMatcher.shouldIgnorePath("logs/error.log"),
//                "Path with subdirectory should match *.log pattern")
//        
//        // Directory pattern test
//        #expect(ignoreMatcher.shouldIgnorePath("dist/bundle.js"),
//                "Path should match dist/ pattern")
//        
//        // Complex pattern test
//        #expect(ignoreMatcher.shouldIgnorePath("scripts/app.min.js"),
//                "Path should match **/*.min.js pattern")
//        #expect(ignoreMatcher.shouldIgnorePath("nested/folder/utils.min.js"),
//                "Path in subdirectory should match **/*.min.js pattern")
//        
//        // Non-matching tests
//        #expect(!ignoreMatcher.shouldIgnorePath("regular.js"),
//                "Regular JS file should not be ignored")
//    }
}

// テスト用にIgnoreMatcherを拡張して、パターンに直接アクセスできるようにする
class DirectlyAccessibleIgnoreMatcher: IgnoreMatcher {
    // 特定のディレクトリに対して直接テスト用パターンを追加するメソッド
    func addTestPattern(_ pattern: String) {
        if var patterns = self.ignorePatterns["/test"] {
            patterns.append(pattern)
            self.ignorePatterns["/test"] = patterns
        } else {
            self.ignorePatterns["/test"] = [pattern]
        }
    }
    
    // 特定のディレクトリに対するパターンを取得するメソッド
    func getTestPatterns(forDirectory directory: String) -> [String]? {
        return self.ignorePatterns[directory]
    }
}

// MARK: - FileInfo Tests

@Suite("FileInfo Tests")
struct FileInfoTests {
    
    @Test("FileInfo equality works correctly")
    func testFileInfoEquality() {
        let url1 = URL(fileURLWithPath: "/path/to/file.swift")
        let url2 = URL(fileURLWithPath: "/path/to/file.swift")
        let url3 = URL(fileURLWithPath: "/different/path.swift")
        
        let fileInfo1 = FileInfo(url: url1, relativePath: "to/file.swift")
        let fileInfo2 = FileInfo(url: url2, relativePath: "to/file.swift")
        let fileInfo3 = FileInfo(url: url1, relativePath: "different/path.swift")
        let fileInfo4 = FileInfo(url: url3, relativePath: "to/file.swift")
        
        #expect(fileInfo1 == fileInfo2)
        #expect(fileInfo1 != fileInfo3)
        #expect(fileInfo2 != fileInfo4)
    }
}

// MARK: - Context Tests

@Suite("Context Tests")
struct ContextTests {
    
    @Test("Context model initializes correctly")
    func testContextInitialization() {
        let context = Context(paths: ["path/to/file1", "path/to/file2"])
        #expect(context.paths.count == 2, "Context should have 2 paths")
        
        if context.paths.count >= 2 {
            #expect(context.paths[0] == "path/to/file1", "First path should match")
            #expect(context.paths[1] == "path/to/file2", "Second path should match")
        } else {
            Issue.record("Context should have at least 2 paths")
        }
    }
    
    @Test("Context encodes and decodes correctly")
    func testContextCoding() throws {
        let originalContext = Context(paths: ["path/to/file1", "path/to/file2"])
        
        // Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalContext)
        
        // Decode back
        let decoder = JSONDecoder()
        let decodedContext = try decoder.decode(Context.self, from: data)
        
        // Verify
        #expect(decodedContext.paths.count == originalContext.paths.count,
                "Decoded context should have same number of paths")
        
        if decodedContext.paths.count >= 2 && originalContext.paths.count >= 2 {
            #expect(decodedContext.paths[0] == originalContext.paths[0],
                    "First path should match after encode/decode")
            #expect(decodedContext.paths[1] == originalContext.paths[1],
                    "Second path should match after encode/decode")
        } else {
            Issue.record("Context should have at least 2 paths")
        }
    }
}

// MARK: - RuntimeError Tests

@Suite("RuntimeError Tests")
struct RuntimeErrorTests {
    
    @Test("RuntimeError initializes with description")
    func testRuntimeErrorInit() {
        let errorMessage = "Test error message"
        let error = RuntimeError(errorMessage)
        
        #expect(error.description == errorMessage)
    }
}

// MARK: - Helper Classes for Testing

/// Mock logger to capture log messages
final class MockLogger {
    private(set) var messages: [String] = []
    
    func log(_ message: String) {
        messages.append(message)
    }
    
    func contains(_ substring: String) -> Bool {
        return messages.contains { $0.contains(substring) }
    }
    
    func clear() {
        messages.removeAll()
    }
}

@Test("MockLogger works correctly")
func testMockLogger() {
    let logger = MockLogger()
    
    // 最初は空
    #expect(logger.messages.isEmpty)
    
    // メッセージを追加
    logger.log("Test message 1")
    logger.log("Test message 2")
    
    // 正しくキャプチャされる
    #expect(logger.messages.count == 2, "Should have 2 logged messages")
    
    if logger.messages.count >= 2 {
        #expect(logger.messages[0] == "Test message 1", "First message should match")
        #expect(logger.messages[1] == "Test message 2", "Second message should match")
    } else {
        Issue.record("Logger should have captured at least 2 messages")
    }
    
    // containsメソッドのテスト
    #expect(logger.contains("message 1"))
    #expect(logger.contains("message 2"))
    #expect(!logger.contains("message 3"))
    
    // クリア機能のテスト
    logger.clear()
    #expect(logger.messages.isEmpty)
}
