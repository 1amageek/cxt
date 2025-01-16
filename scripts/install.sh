#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Xcode Command Line Tools are installed
if ! command_exists xcode-select; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "Please run this script again after the installation completes."
    exit 1
fi

# Build the package
echo "Building CXT..."
swift build -c release

# Create bin directory if it doesn't exist
if [ ! -d "$HOME/.local/bin" ]; then
    mkdir -p "$HOME/.local/bin"
fi

# Copy the binary
echo "Installing CXT to $HOME/.local/bin..."
cp -f .build/release/cxt "$HOME/.local/bin/cxt"

# Make the binary executable
chmod +x "$HOME/.local/bin/cxt"

# Check if PATH includes ~/.local/bin
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    # Detect shell and add to appropriate config file
    SHELL_NAME=$(basename "$SHELL")
    case $SHELL_NAME in
        "bash")
            CONFIG_FILE="$HOME/.bashrc"
            ;;
        "zsh")
            CONFIG_FILE="$HOME/.zshrc"
            ;;
        *)
            echo "Warning: Unsupported shell. Please add $HOME/.local/bin to your PATH manually."
            exit 1
            ;;
    esac

    echo "Adding $HOME/.local/bin to PATH in $CONFIG_FILE..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$CONFIG_FILE"
    echo "Please restart your terminal or run: source $CONFIG_FILE"
fi

echo "CXT has been installed successfully!"
echo "You can now use 'cxt' command from anywhere."
echo "Run 'cxt --help' for usage information."