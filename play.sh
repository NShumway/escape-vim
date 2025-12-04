#!/bin/bash
# Launch Escape Vim
cd "$(dirname "$0")"
VIMRUNTIME=./runtime ./src/vim --clean -S game/ui/init.vim
