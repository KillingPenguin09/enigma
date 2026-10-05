#!/bin/bash
set -e

echo "Installing Enigma..."

ENIGMA_SHARE="$HOME/.local/share/enigma"
ENIGMA_CONFIG="$HOME/.config/enigma"
QUICKSHELL_CONFIG="$HOME/.config/quickshell"

mkdir -p "$ENIGMA_SHARE" "$ENIGMA_CONFIG"

# Copy source files
echo "Copying source files to $ENIGMA_SHARE..."
cp -rf bin "$ENIGMA_SHARE/"
cp -rf src "$ENIGMA_SHARE/"

# Copy quickshell config
echo "Copying quickshell config to $QUICKSHELL_CONFIG..."
if [ -d "$QUICKSHELL_CONFIG" ]; then
    echo "Backing up existing quickshell config..."
    mv "$QUICKSHELL_CONFIG" "${QUICKSHELL_CONFIG}.bak"
fi
cp -rf src/quickshell "$QUICKSHELL_CONFIG"

echo "Installation complete!"
