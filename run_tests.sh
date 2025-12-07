#!/bin/bash
#
# Unified test runner for Escape Vim
# Usage:
#   ./run_tests.sh              # Run all tests
#   ./run_tests.sh vim          # Run only Vim tests
#   ./run_tests.sh python       # Run only Python tests
#   ./run_tests.sh --coverage   # Run with coverage report
#   ./run_tests.sh --quick      # Quick smoke test (for pre-commit)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track results
VIM_RESULT=0
VIM_PASSED=0
VIM_FAILED=0
PYTHON_RESULT=0

# Parse arguments
RUN_VIM=true
RUN_PYTHON=true
COVERAGE=false
QUICK=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    vim)
      RUN_VIM=true
      RUN_PYTHON=false
      shift
      ;;
    python)
      RUN_VIM=false
      RUN_PYTHON=true
      shift
      ;;
    --coverage|-c)
      COVERAGE=true
      shift
      ;;
    --quick|-q)
      QUICK=true
      shift
      ;;
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [vim|python] [--coverage] [--quick] [--verbose]"
      echo ""
      echo "Options:"
      echo "  vim         Run only Vim tests"
      echo "  python      Run only Python tests"
      echo "  --coverage  Generate coverage report (Python only)"
      echo "  --quick     Run quick smoke tests only"
      echo "  --verbose   Verbose output"
      echo "  --help      Show this help message"
      exit 0
      ;;
    *)
      # Check if it's a specific test file
      if [[ -f "$1" ]]; then
        if [[ "$1" == *.vim ]]; then
          RUN_VIM=true
          RUN_PYTHON=false
          VIM_TEST_FILE="$1"
        elif [[ "$1" == *.py ]]; then
          RUN_VIM=false
          RUN_PYTHON=true
          PYTHON_TEST_FILE="$1"
        fi
      fi
      shift
      ;;
  esac
done

print_header() {
  echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
}

print_result() {
  if [ $1 -eq 0 ]; then
    echo -e "${GREEN}✓ $2${NC}"
  else
    echo -e "${RED}✗ $2${NC}"
  fi
}

# ============================================================================
# Vim Tests (using Vim's built-in assert functions)
# ============================================================================
run_vim_tests() {
  print_header "Running Vim Tests"

  # Use custom Vim if available
  VIM_BIN="vim"
  if [ -x "src/vim" ]; then
    VIM_BIN="./src/vim"
  fi

  echo -e "${BLUE}Using Vim: $VIM_BIN${NC}"
  echo ""

  # Find test files
  if [ -n "$VIM_TEST_FILE" ]; then
    TEST_FILES="$VIM_TEST_FILE"
  elif [ "$QUICK" = true ]; then
    # Quick mode: just run one test file
    TEST_FILES="tests/vim/unit/test_position.vim"
  else
    TEST_FILES=$(find tests/vim/unit -name "test_*.vim" 2>/dev/null | sort)
  fi

  if [ -z "$TEST_FILES" ]; then
    echo -e "${YELLOW}No Vim test files found${NC}"
    return 0
  fi

  echo "Test files:"
  for f in $TEST_FILES; do
    echo "  - $f"
  done
  echo ""

  # Run tests
  FAILED_FILES=""

  for test_file in $TEST_FILES; do
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Running: $test_file${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Run Vim with the test script, capture output
    output=$($VIM_BIN -u NONE -N -c "set encoding=utf-8" -c "source $test_file" 2>&1 | grep -v Warning | grep -v "More --" || true)

    # Show test results
    echo "$output" | grep -E "^(PASS|FAIL|ERROR|Results):" || true

    # Extract results for this file
    passed=$(echo "$output" | grep -oE "([0-9]+) passed" | grep -oE "[0-9]+" || echo "0")
    failed=$(echo "$output" | grep -oE "([0-9]+) failed" | grep -oE "[0-9]+" || echo "0")

    VIM_PASSED=$((VIM_PASSED + passed))
    VIM_FAILED=$((VIM_FAILED + failed))

    if [ "$failed" -gt 0 ]; then
      FAILED_FILES="$FAILED_FILES $test_file"
      VIM_RESULT=1
    fi

    echo ""
  done

  # Summary
  echo -e "${BLUE}───────────────────────────────────────────────────────────────${NC}"
  echo -e "Vim Tests: ${GREEN}$VIM_PASSED passed${NC}, ${RED}$VIM_FAILED failed${NC}"

  if [ -n "$FAILED_FILES" ]; then
    echo -e "\n${RED}Failed test files:${NC}"
    for f in $FAILED_FILES; do
      echo "  - $f"
    done
  fi

  return $VIM_RESULT
}

# ============================================================================
# Python Tests
# ============================================================================
run_python_tests() {
  print_header "Running Python Tests"

  # Check if pytest is installed
  if ! command -v pytest &> /dev/null; then
    echo -e "${YELLOW}pytest not found. Installing...${NC}"
    pip install pytest pytest-cov pyyaml
  fi

  # Build pytest arguments
  PYTEST_ARGS="-v"

  if [ "$COVERAGE" = true ]; then
    PYTEST_ARGS="$PYTEST_ARGS --cov=tools --cov-report=term-missing --cov-report=html:tests/coverage"
  fi

  if [ "$QUICK" = true ]; then
    PYTEST_ARGS="$PYTEST_ARGS -x --tb=line"
  fi

  if [ -n "$PYTHON_TEST_FILE" ]; then
    PYTEST_ARGS="$PYTEST_ARGS $PYTHON_TEST_FILE"
  else
    PYTEST_ARGS="$PYTEST_ARGS tests/python/"
  fi

  echo "Running: pytest $PYTEST_ARGS"
  echo ""

  if pytest $PYTEST_ARGS; then
    PYTHON_RESULT=0
  else
    PYTHON_RESULT=1
  fi

  return $PYTHON_RESULT
}

# ============================================================================
# Main
# ============================================================================

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║               Escape Vim Test Suite                           ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

OVERALL_RESULT=0

if [ "$RUN_VIM" = true ]; then
  run_vim_tests || OVERALL_RESULT=1
fi

if [ "$RUN_PYTHON" = true ]; then
  run_python_tests || OVERALL_RESULT=1
fi

# ============================================================================
# Summary
# ============================================================================
print_header "Test Summary"

if [ "$RUN_VIM" = true ]; then
  print_result $VIM_RESULT "Vim tests ($VIM_PASSED passed, $VIM_FAILED failed)"
fi

if [ "$RUN_PYTHON" = true ]; then
  print_result $PYTHON_RESULT "Python tests"
fi

echo ""
if [ $OVERALL_RESULT -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
else
  echo -e "${RED}Some tests failed.${NC}"
fi

exit $OVERALL_RESULT
