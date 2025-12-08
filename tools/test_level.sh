#!/bin/bash
# Test a level standalone (bypasses game UI)
# Usage: ./tools/test_level.sh level03
#        ./tools/test_level.sh (defaults to level01)

LEVEL="${1:-level01}"

# Find the vim binary - prefer our bundled one
if [ -x "./src/vim" ]; then
  VIM="./src/vim"
elif [ -x "./vim" ]; then
  VIM="./vim"
else
  VIM="vim"
fi

echo "Testing level: $LEVEL"
echo "Using vim: $VIM"
echo ""

$VIM --clean -c "source game/debug.vim" -c "source levels/api/level.vim" -c "call Level_Load('levels/$LEVEL')"
