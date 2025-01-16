# CXT

A command-line tool to concatenate files with specified extension and copy to clipboard as markdown.

## Features

- Search for files with specified extension in a directory
- Concatenate file contents with frontmatter in markdown format
- Add file paths as section headers
- Copy the result to clipboard
- Support for code block syntax highlighting

## Installation

### Using Homebrew

```bash
brew tap 1amageek/cxt
brew install cxt
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/1amageek/cxt.git
cd cxt

# Run the install script
./scripts/install.sh
```

## Usage

Basic command format:
```bash
cxt <extension> <directory-path>
```

Examples:
```bash
# Concatenate Swift files in current directory
cxt swift ./

# Concatenate Markdown files in Documents
cxt md ~/Documents/notes

# Show help
cxt --help

# Show version
cxt --version
```

## Output Format

The tool creates a markdown document with the following format:

```markdown
---
created_at: 2025-01-16 10:30:00
extension: swift
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
```

## Requirements

- macOS 14.0 or later
- Xcode 14.0 or later

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License