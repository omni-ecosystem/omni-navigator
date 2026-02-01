#!/bin/bash

set -e

REPO_URL="git@github.com:omni-ecosystem/omni-navigator.git"
INSTALL_DIR="$HOME/.omni-ecosystem"
TARGET_DIR="$INSTALL_DIR/omni-navigator"
UI_KIT_DIR="$INSTALL_DIR/omni-ui-kit"
UI_KIT_INSTALL_URL="https://raw.githubusercontent.com/omni-ecosystem/omni-ui-kit/refs/heads/main/install.sh"

echo "=== Omni Navigator Installer ==="
echo ""

# Check for omni-ui-kit dependency
if [ ! -d "$UI_KIT_DIR" ]; then
    echo "⚠️  Dependency missing: omni-ui-kit not found"
    echo "Installing omni-ui-kit first..."
    echo ""

    # Download and run omni-ui-kit install script
    curl -fsSL "$UI_KIT_INSTALL_URL" | bash

    echo ""
    echo "Continuing with omni-navigator installation..."
    echo ""
fi

# Create installation directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
    echo "Creating installation directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
fi

# Check if omni-navigator already exists
if [ -d "$TARGET_DIR" ]; then
    echo "omni-navigator already exists at $TARGET_DIR"
    echo "Updating existing installation..."

    cd "$TARGET_DIR"

    # Check if it's a git repository
    if [ -d ".git" ]; then
        echo "Fetching latest changes..."
        git fetch origin

        echo "Pulling updates..."
        git pull origin main || git pull origin master

        echo ""
        echo "✓ Update complete!"
    else
        echo "ERROR: $TARGET_DIR exists but is not a git repository"
        exit 1
    fi
else
    echo "Installing omni-navigator to $TARGET_DIR..."

    cd "$INSTALL_DIR"
    git clone "$REPO_URL"

    echo ""
    echo "✓ Installation complete!"
fi

echo ""
echo "omni-navigator is located at: $TARGET_DIR"
