#!/bin/bash
# Uninstall Escape Vim
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="$HOME/.escape-vim"
BIN_LINK="/usr/local/bin/escape-vim"
SAVE_DIR="$HOME/Library/Application Support/EscapeVim"

echo ""
echo "  Uninstalling Escape Vim"
echo "  ═══════════════════════"
echo ""

# Check if installed
if [ ! -d "$INSTALL_DIR" ]; then
    echo "Escape Vim is not installed at $INSTALL_DIR"
    exit 0
fi

# Ask about save data
if [ -d "$SAVE_DIR" ]; then
    echo -e "${YELLOW}Save data found at:${NC}"
    echo "  $SAVE_DIR"
    echo ""
    read -p "Delete save data too? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$SAVE_DIR"
        echo -e "${GREEN}✓ Save data deleted${NC}"
    else
        echo "  Save data preserved."
    fi
fi

# Remove symlink
if [ -L "$BIN_LINK" ]; then
    sudo rm -f "$BIN_LINK" 2>/dev/null || true
    echo -e "${GREEN}✓ Removed /usr/local/bin/escape-vim${NC}"
fi

# Remove installation
rm -rf "$INSTALL_DIR"
echo -e "${GREEN}✓ Removed $INSTALL_DIR${NC}"

echo ""
echo -e "${GREEN}Escape Vim has been uninstalled.${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} If you added an alias to ~/.zshrc, you may want to remove it manually."
echo ""
