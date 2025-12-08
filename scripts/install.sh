#!/bin/bash
# Install Escape Vim
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

INSTALL_DIR="$HOME/.escape-vim"
BIN_LINK="/usr/local/bin/escape-vim"

echo ""
echo "  ╔═══════════════════════════════════════╗"
echo "  ║         Installing Escape Vim         ║"
echo "  ╚═══════════════════════════════════════╝"
echo ""

# Check if running from extracted release
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ ! -f "$SCRIPT_DIR/vim" ]; then
    echo -e "${RED}Error: This script must be run from the extracted release directory.${NC}"
    echo "Make sure 'vim' binary exists in the same directory as this script."
    exit 1
fi

# Check architecture
ARCH=$(uname -m)
if [ "$ARCH" != "arm64" ]; then
    echo -e "${YELLOW}Warning: This release is built for Apple Silicon (arm64).${NC}"
    echo "Your architecture: $ARCH"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check for existing installation
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Existing installation found at $INSTALL_DIR${NC}"
    read -p "Replace it? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    rm -rf "$INSTALL_DIR"
fi

# Install files
echo "Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp -r "$SCRIPT_DIR/vim" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/game" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/levels" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/runtime" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/assets" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/escape-vim" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/LICENSE" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/README.md" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/uninstall.sh" "$INSTALL_DIR/"

chmod +x "$INSTALL_DIR/vim"
chmod +x "$INSTALL_DIR/escape-vim"

# Create symlink in /usr/local/bin
echo "Creating command 'escape-vim'..."
if [ -L "$BIN_LINK" ] || [ -f "$BIN_LINK" ]; then
    sudo rm -f "$BIN_LINK"
fi

# Try to create symlink, fall back to shell alias if sudo fails
if sudo ln -sf "$INSTALL_DIR/escape-vim" "$BIN_LINK" 2>/dev/null; then
    echo -e "${GREEN}✓ Command 'escape-vim' is now available${NC}"
else
    echo -e "${YELLOW}Could not create /usr/local/bin symlink (sudo required)${NC}"
    echo ""
    echo "Add this alias to your shell config (~/.zshrc or ~/.bashrc):"
    echo ""
    echo "  alias escape-vim='$INSTALL_DIR/escape-vim'"
    echo ""

    # Offer to add it automatically
    read -p "Add alias to ~/.zshrc automatically? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "" >> "$HOME/.zshrc"
        echo "# Escape Vim" >> "$HOME/.zshrc"
        echo "alias escape-vim='$INSTALL_DIR/escape-vim'" >> "$HOME/.zshrc"
        echo -e "${GREEN}✓ Alias added to ~/.zshrc${NC}"
        echo "  Run 'source ~/.zshrc' or restart your terminal."
    fi
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Installation Complete!          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo "To play, run:"
echo ""
echo "  escape-vim"
echo ""
echo "To uninstall later, run:"
echo ""
echo "  ~/.escape-vim/uninstall.sh"
echo ""
