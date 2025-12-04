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

VIMRUNTIME=./runtime ./src/vim --clean -S game/ui/init.vim
