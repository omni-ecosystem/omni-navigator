#!/bin/bash

set -e

TARGET_DIR="$HOME/.omni-ecosystem/omni-navigator"

echo "=== Omni Navigator Uninstaller ==="
echo ""

# Check if omni-navigator exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "omni-navigator not found at: $TARGET_DIR"
    echo "Nothing to uninstall."
    exit 0
fi

echo "WARNING: This will remove omni-navigator:"
echo "  $TARGET_DIR"
echo ""
echo "Note: This will NOT remove omni-ui-kit (dependency)"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo ""

if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Removing $TARGET_DIR..."
    rm -rf "$TARGET_DIR"
    echo ""
    echo "✓ Uninstallation complete!"
else
    echo "Uninstallation cancelled."
    exit 0
fi
