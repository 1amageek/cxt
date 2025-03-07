# CXT

A command-line tool to concatenate files with specified extensions and copy to clipboard as markdown, with AI-powered context filtering.

## Features

- Search for files with specified extensions in a directory
- Concatenate file contents with frontmatter in markdown format
- Add file paths as section headers
- Filter files based on contextual relevance using AI (optional)
- Copy the result to clipboard
- Support for code block syntax highlighting

## Installation

```bash
brew tap 1amageek/cxt https://github.com/1amageek/cxt.git
brew install 1amageek/cxt/cxt
```

### API Key Setup

To use the context filtering feature with Gemini AI, you need to set up a Google AI API key:

1. Get your API key from [Google AI Studio](https://aistudio.google.com/)
2. Set the environment variable:

```bash
export GOOGLE_GENAI_API_KEY=your_api_key_here
```

To make the API key persistent across terminal sessions, add it to your shell profile:

```bash
# For Bash (add to ~/.bashrc or ~/.bash_profile)
echo 'export GOOGLE_GENAI_API_KEY=your_api_key_here' >> ~/.bash_profile

# For Zsh (add to ~/.zshrc)
echo 'export GOOGLE_GENAI_API_KEY=your_api_key_here' >> ~/.zshrc
```

## Usage

Basic command format:
```bash
cxt <extensions> <directory-path> [prompt]
```

Examples:
```bash
# Concatenate Swift files in current directory
cxt swift ./

# Concatenate multiple file types in Documents (comma-separated)
cxt swift,md,json ~/Documents

# Filter Swift files related to networking functionality
cxt swift ./MyProject "Find files related to networking and HTTP requests"

# Run with verbose output for debugging
cxt -v swift ./MyProject

# Show help
cxt --help

# Show version
cxt --version
```

## Context Filtering

The optional prompt parameter activates context-aware filtering:

```bash
cxt swift ./MyApp "Find files related to authentication"
```

> **Note**: Context filtering requires a valid Google AI API key. See the [API Key Setup](#api-key-setup) section.

This uses the Gemini AI model to:
1. Analyze all matching files
2. Extract only files relevant to the specified context
3. Return a filtered markdown document with just the relevant files

## Output Format

The tool creates a markdown document with the following format:

~~~markdown
---
created_at: 2025-03-07 15:30:00
extensions: [.swift, .md]
base_path: /path/to/directory
---

# path/to/file1.swift

```swift
// Content of file1.swift
```

# path/to/file2.md

```md
// Content of file2.md
```
~~~

## Requirements

- macOS 15.0 or later
- Swift 6.0 or later
- Requires SwiftAgent package
- Google AI API key (for context filtering feature)

## License

MIT License
