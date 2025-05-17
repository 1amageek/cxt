# CXT

A powerful command-line tool for developers to extract and share code context. CXT concatenates files with specified extensions and formats them as markdown with proper syntax highlighting.

## Features

- **Intelligent File Collection**: Search for files with specified extensions across directory structures
- **Markdown Formatting**: Generate well-structured markdown documents with proper syntax highlighting
- **Clipboard Integration**: Automatically copy formatted output to clipboard on macOS
- **Smart Ignore System**: Respect `.gitignore` and `.clineignore` files at every directory level
- **Path Expansion**: Support for home directory (`~`) and relative paths
- **Customizable Filtering**: Add additional ignore patterns through command-line options
- **Developer-Friendly Output**: Clear indication of processed files and filtered results

## Installation

```bash
brew tap 1amageek/cxt https://github.com/1amageek/cxt.git
brew install 1amageek/cxt/cxt
```

## Usage

### Basic Command Format
```bash
cxt <extensions> <directory-path> [options]
```

### Arguments

- `<extensions>`: File extensions to search for (comma-separated, without dots)
  - Example: `swift` or `swift,md,json`
- `<directory-path>`: Directory path to search in (supports ~ for home directory)
  - Example: `./` or `~/Projects/MyApp`

### Options

- `-v`: Enable verbose output for detailed processing information
- `-i <patterns>`: Additional ignore patterns (comma-separated)
  - Example: `-i "Tests/,*.generated.swift"`
- `--help`: Show the help information and command descriptions

### Examples

```bash
# Basic: Swift files in current directory
cxt swift ./

# Multiple file types: Swift, Markdown, and JSON files
cxt swift,md,json ~/Documents

# Web development: TS, TSX, and CSS files, ignoring node_modules
cxt ts,tsx,css . -i node_modules


# Verbose mode with custom ignore patterns
cxt -v swift ./MyProject -i "Tests/,*.generated.swift"


# Use in a directory with spaces
cxt swift "~/My Projects/Swift App"

```

## Ignore File Support

CXT intelligently handles file exclusions to ensure you process only the relevant files.

### Default Ignore Behavior

CXT respects the following ignore files at every directory level:

- `.gitignore` - Standard Git ignore patterns
- `.clineignore` - Custom ignore patterns specific to CXT

### Built-in Ignore Patterns

By default, CXT automatically ignores these common directories and files:

- `node_modules/` - NPM dependencies
- `.git/` - Git repository metadata
- `.DS_Store` - macOS filesystem metadata
- `.build/` - Swift build artifacts
- `*.xcodeproj` - Xcode project files

### Custom Ignore Patterns

To add project-specific ignore patterns, you can:

1. Create a `.clineignore` file in your project directories
2. Use the `--ignore-patterns` command-line option

#### Using .clineignore Files

Creating a `.clineignore` file uses the same pattern format as `.gitignore`:

```
# Example .clineignore file
# Ignore build artifacts
dist/
build/

# Ignore generated code
*.generated.swift

# Ignore temporary files
*.tmp
```

#### Using --ignore-patterns Option

For temporary or ad-hoc ignores, use the command-line option:

```bash
# Ignore all test files in addition to default ignores
cxt swift ./MyProject --ignore-patterns="*_test.swift,*_spec.swift,Tests/"

# Ignore generated files and documentation
cxt swift,md ./MyProject --ignore-patterns="*.generated.swift,docs/"

# Combine verbose mode with custom ignore patterns
cxt -v swift ./MyProject --ignore-patterns="build/,*.tmp"
```

### Ignore Pattern Syntax

CXT supports standard glob pattern syntax:

- `*` - Matches any number of characters (except /)
- `**` - Matches any number of directories recursively
- `?` - Matches a single character
- `[abc]` - Matches one character in the brackets
- `dir/` - Trailing slash indicates a directory match
- `#` - Lines starting with # are comments

## Output Format

CXT generates a well-structured markdown document that's perfect for sharing code context with AI assistants or colleagues.

### Markdown Format

The output follows this format:

~~~markdown
---
created_at: 2025-04-15 10:51:17
extensions: [.swift]
base_path: /path/to/directory
---

# path/to/file1.swift

```swift
// Content of file1.swift
```

# path/to/file2.swift

```swift
// Content of file2.swift
```
~~~

### Output Components

1. **Frontmatter Header**:
   - `created_at`: Timestamp when the document was generated
   - `extensions`: List of file extensions included in the document
   - `base_path`: The root directory where the scan started

2. **File Sections**:
   - Each file is represented as a heading with its relative path
   - File content is enclosed in a code block with appropriate language syntax highlighting

### Clipboard Integration

The formatted content is automatically copied to your clipboard on macOS, making it ready to:

- Paste into AI assistants like Claude, ChatGPT, or Gemini
- Share with colleagues via messaging platforms
- Insert into documentation or wikis
- Use with other text processing tools

This seamless clipboard integration eliminates the need for manual copying or file handling.

## Requirements

### System Requirements
- macOS 14.0 or later
- Swift 6.0 or later

### Dependencies
CXT is built using the following Swift packages:
- [Swift Argument Parser](https://github.com/apple/swift-argument-parser.git) - For command-line interface


## Use Cases

CXT is especially useful for:

- **AI Prompt Engineering**: Prepare code context for LLMs (Claude, ChatGPT, Gemini)
- **Web Development**: Extract TS, JS, and CSS files from React or Angular projects
- **Mobile Development**: Gather Swift files for iOS or Kotlin for Android
- **Code Reviews**: Share relevant parts of a codebase with colleagues
- **Documentation**: Extract code samples for technical documentation
- **Debugging**: Collect related files to understand an issue's scope
- **Onboarding**: Help new team members understand specific parts of a codebase

### Web Development Example

For a typical React or Next.js project:

```bash
# Extract all TS/TSX/CSS files, ignoring node_modules
cxt ts,tsx,css . -i node_modules

```

### Mobile Development Example

When working on iOS apps:

```bash
# Extract SwiftUI views
cxt swift ./Sources -i "Tests/,*.generated.swift"
```

## License

MIT License

---

Created by [1amageek](https://github.com/1amageek)
