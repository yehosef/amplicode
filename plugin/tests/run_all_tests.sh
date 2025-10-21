#!/bin/bash
# run_all_tests.sh - Master test runner for Amplicode plugin
# Runs all test scripts and provides summary

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Check if colors are supported
if [ ! -t 1 ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    NC=''
fi

echo -e "${BOLD}========================================"
echo "Amplicode Plugin Test Suite"
echo -e "========================================${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test configuration
TESTS=(
    "test_macos_setup.sh:Prerequisites Check:CRITICAL"
    "test_hook_performance.sh:Hook Performance:CRITICAL"
    "test_multi_session.sh:Data Safety:CRITICAL"
    "test_sandbox.sh:Sandbox Compatibility:IMPORTANT"
)

# Results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Array to store failed tests
FAILED_TEST_NAMES=()

# Function to run a single test
run_test() {
    local test_file="$1"
    local test_name="$2"
    local priority="$3"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -e "${BOLD}Test $TOTAL_TESTS: $test_name${NC} ${YELLOW}[$priority]${NC}"
    echo "----------------------------------------"

    if [ ! -f "$SCRIPT_DIR/$test_file" ]; then
        echo -e "${YELLOW}⚠️  SKIP: Test file not found${NC}"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        echo ""
        return
    fi

    # Run test and capture exit code
    if bash "$SCRIPT_DIR/$test_file"; then
        echo -e "${GREEN}✅ PASSED${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}❌ FAILED${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$test_name ($test_file)")
    fi

    echo ""
}

# Run all tests
for test_spec in "${TESTS[@]}"; do
    IFS=':' read -r test_file test_name priority <<< "$test_spec"
    run_test "$test_file" "$test_name" "$priority"
done

# Summary
echo -e "${BOLD}========================================"
echo "Test Suite Summary"
echo -e "========================================${NC}"
echo ""

echo "Total tests run: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}"
echo -e "${YELLOW}Skipped: $SKIPPED_TESTS${NC}"

echo ""

# Determine overall result
if [ $FAILED_TESTS -eq 0 ]; then
    if [ $SKIPPED_TESTS -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✅ ALL TESTS PASSED${NC}"
        echo ""
        echo "Amplicode plugin is ready for deployment!"
        EXIT_CODE=0
    else
        echo -e "${YELLOW}${BOLD}⚠️  TESTS PASSED WITH SKIPS${NC}"
        echo ""
        echo "Some tests were skipped. Review above for details."
        EXIT_CODE=0
    fi
else
    echo -e "${RED}${BOLD}❌ TESTS FAILED${NC}"
    echo ""
    echo "Failed tests:"
    for failed_test in "${FAILED_TEST_NAMES[@]}"; do
        echo -e "  ${RED}• $failed_test${NC}"
    done
    echo ""
    echo "Fix failing tests before deployment."
    EXIT_CODE=1
fi

# Exit with appropriate code
exit $EXIT_CODE
