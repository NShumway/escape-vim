#!/bin/bash
# Launch Escape Vim
cd "$(dirname "$0")"

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

# Development mode: enable debug logging by default
# Production builds (app bundle) don't use play.sh and won't have this set
VIMRUNTIME=./runtime ./src/vim --clean -c "let g:escape_vim_debug=1" -S game/ui/init.vim
