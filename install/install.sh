#!/bin/bash
set -e

echo "Starting Enigma installation..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Packages to install
PACMAN_PKGS=(
    qt6-declarative qt6-svg qt6-wayland qt6-5compat
    imagemagick jq socat grim slurp wl-clipboard
    brightnessctl python python-pillow wireplumber libpulse
    unzip curl wget
)

AUR_PKGS=(
    quickshell-git
    matugen-bin
)

echo "Installing system dependencies via pacman..."
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

# Helper to find AUR helper
if command -v paru &> /dev/null; then
    AUR_HELPER="paru"
elif command -v yay &> /dev/null; then
    AUR_HELPER="yay"
else
    echo "Could not find paru or yay. Please install them to install AUR dependencies:"
    echo "${AUR_PKGS[*]}"
    AUR_HELPER=""
fi

if [ -n "$AUR_HELPER" ]; then
    echo "Installing AUR dependencies via $AUR_HELPER..."
    $AUR_HELPER -S --needed --noconfirm "${AUR_PKGS[@]}"
fi

ENIGMA_SHARE="$HOME/.local/share/enigma"
ENIGMA_CONFIG="$HOME/.config/enigma"
QUICKSHELL_CONFIG="$HOME/.config/quickshell"

echo "Setting up directories..."
mkdir -p "$ENIGMA_SHARE" "$ENIGMA_CONFIG"

# Copy source files
echo "Copying source files to $ENIGMA_SHARE..."
cp -rf "$REPO_ROOT/bin" "$ENIGMA_SHARE/"
cp -rf "$REPO_ROOT/src" "$ENIGMA_SHARE/"

# Copy quickshell config
echo "Copying quickshell config to $QUICKSHELL_CONFIG..."
if [ -d "$QUICKSHELL_CONFIG" ]; then
    echo "Backing up existing quickshell config to ${QUICKSHELL_CONFIG}.bak..."
    mv "$QUICKSHELL_CONFIG" "${QUICKSHELL_CONFIG}.bak"
fi
cp -rf "$REPO_ROOT/src/quickshell" "$QUICKSHELL_CONFIG"

echo "Installation complete!"
