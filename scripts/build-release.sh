#!/bin/bash
# Build a release tarball for distribution
set -e

cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

# Get version from git tag or use default
VERSION=${1:-$(git describe --tags 2>/dev/null || echo "0.1.0")}
RELEASE_NAME="escape-vim-${VERSION}-macos-arm64"
BUILD_DIR="$PROJECT_ROOT/dist"
RELEASE_DIR="$BUILD_DIR/$RELEASE_NAME"

echo "Building Escape Vim $VERSION..."

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$RELEASE_DIR"

# Build vim if needed
if [ ! -f "$PROJECT_ROOT/src/vim" ]; then
    echo "Building Vim from source..."
    cd "$PROJECT_ROOT/src"
    make -j$(sysctl -n hw.ncpu)
    cd "$PROJECT_ROOT"
fi

# Verify binary exists
if [ ! -f "$PROJECT_ROOT/src/vim" ]; then
    echo "Error: Vim binary not found. Run 'make' in src/ first."
    exit 1
fi

echo "Packaging release..."

# Copy binary
cp "$PROJECT_ROOT/src/vim" "$RELEASE_DIR/vim"

# Copy game files
cp -r "$PROJECT_ROOT/game" "$RELEASE_DIR/game"
cp -r "$PROJECT_ROOT/levels" "$RELEASE_DIR/levels"
cp -r "$PROJECT_ROOT/runtime" "$RELEASE_DIR/runtime"
cp -r "$PROJECT_ROOT/assets" "$RELEASE_DIR/assets"

# Remove development files from the release
find "$RELEASE_DIR" -name "*.c" -delete
find "$RELEASE_DIR" -name "*.h" -delete
find "$RELEASE_DIR" -name "*.o" -delete
find "$RELEASE_DIR" -name ".gitkeep" -delete
find "$RELEASE_DIR" -name ".DS_Store" -delete
rm -rf "$RELEASE_DIR/assets/mockups"
rm -rf "$RELEASE_DIR/assets/fireworks_final"

# Copy scripts and docs
cp "$PROJECT_ROOT/scripts/install.sh" "$RELEASE_DIR/"
cp "$PROJECT_ROOT/scripts/uninstall.sh" "$RELEASE_DIR/"
cp "$PROJECT_ROOT/LICENSE" "$RELEASE_DIR/"
cp "$PROJECT_ROOT/README.md" "$RELEASE_DIR/"

# Create the play script for the release
cat > "$RELEASE_DIR/escape-vim" << 'EOF'
#!/bin/bash
# Launch Escape Vim
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Handle --reset flag
if [ "$1" = "--reset" ]; then
    SAVE_DIR="$HOME/Library/Application Support/EscapeVim"
    if [ -d "$SAVE_DIR" ]; then
        rm -rf "$SAVE_DIR"
        echo "Save data cleared."
    else
        echo "No save data found."
    fi
    exit 0
fi

# Handle --help flag
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Escape Vim - Learn Vim by escaping mazes"
    echo ""
    echo "Usage: escape-vim [options]"
    echo ""
    echo "Options:"
    echo "  --reset    Clear all save data"
    echo "  --help     Show this help message"
    echo ""
    exit 0
fi

VIMRUNTIME="$SCRIPT_DIR/runtime" "$SCRIPT_DIR/vim" --clean -S "$SCRIPT_DIR/game/ui/init.vim"
EOF
chmod +x "$RELEASE_DIR/escape-vim"

# Create tarball
cd "$BUILD_DIR"
tar -czf "${RELEASE_NAME}.tar.gz" "$RELEASE_NAME"

echo ""
echo "Release built successfully!"
echo "  Tarball: $BUILD_DIR/${RELEASE_NAME}.tar.gz"
echo "  Size: $(du -h "${RELEASE_NAME}.tar.gz" | cut -f1)"
echo ""
echo "To test locally:"
echo "  cd $RELEASE_DIR && ./escape-vim"
