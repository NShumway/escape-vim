#!/bin/bash
#
# Run Vim unit tests using Vim's built-in assert functions
# Usage:
#   ./run_vim_tests.sh                    # Run all tests
#   ./run_vim_tests.sh test_position.vim  # Run specific test
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$REPO_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Use custom Vim if available
VIM_BIN="vim"
if [ -x "$REPO_ROOT/src/vim" ]; then
  VIM_BIN="$REPO_ROOT/src/vim"
fi

echo -e "${BLUE}Using Vim: $VIM_BIN${NC}"
echo ""

# Find test files
if [ -n "$1" ]; then
  if [ -f "$1" ]; then
    TEST_FILES="$1"
  elif [ -f "tests/vim/unit/$1" ]; then
    TEST_FILES="tests/vim/unit/$1"
  else
    echo -e "${RED}Test file not found: $1${NC}"
    exit 1
  fi
else
  TEST_FILES=$(find tests/vim/unit -name "test_*.vim" 2>/dev/null | sort)
fi

if [ -z "$TEST_FILES" ]; then
  echo -e "${YELLOW}No test files found${NC}"
  exit 0
fi

echo "Test files:"
for f in $TEST_FILES; do
  echo "  - $f"
done
echo ""

# Run tests
TOTAL_PASSED=0
TOTAL_FAILED=0
FAILED_FILES=""

for test_file in $TEST_FILES; do
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}Running: $test_file${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Run Vim with the test script
  output=$($VIM_BIN -u NONE -N -c "set encoding=utf-8" -c "source $test_file" 2>&1 | grep -v Warning | grep -v "More --" || true)

  echo "$output" | grep -E "^(PASS|FAIL|ERROR|Results):" || true

  # Extract results
  passed=$(echo "$output" | grep -oE "([0-9]+) passed" | grep -oE "[0-9]+" || echo "0")
  failed=$(echo "$output" | grep -oE "([0-9]+) failed" | grep -oE "[0-9]+" || echo "0")

  TOTAL_PASSED=$((TOTAL_PASSED + passed))
  TOTAL_FAILED=$((TOTAL_FAILED + failed))

  if [ "$failed" -gt 0 ]; then
    FAILED_FILES="$FAILED_FILES $test_file"
  fi

  echo ""
done

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                        SUMMARY                                ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "Total: ${GREEN}$TOTAL_PASSED passed${NC}, ${RED}$TOTAL_FAILED failed${NC}"

if [ -n "$FAILED_FILES" ]; then
  echo -e "\n${RED}Failed test files:${NC}"
  for f in $FAILED_FILES; do
    echo "  - $f"
  done
fi

if [ "$TOTAL_FAILED" -gt 0 ]; then
  exit 1
else
  echo -e "\n${GREEN}All tests passed!${NC}"
  exit 0
fi
