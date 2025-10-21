#!/bin/bash
# test_hook_performance.sh - Verify hooks execute in <50ms
# Critical test: Hook performance directly impacts Claude Code responsiveness
# FAIL if average execution time >50ms

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if colors are supported
if [ ! -t 1 ]; then
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

echo "=== Hook Performance Test ==="
echo "Target: <50ms per hook call"
echo "Running 10 iterations per hook..."
echo ""

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$PLUGIN_DIR/hooks"

# Test configuration
ITERATIONS=10
MAX_AVG_MS=50
EXIT_CODE=0

# Function to test a hook's performance
test_hook_performance() {
    local hook_file="$1"
    local hook_name="$(basename "$hook_file")"

    if [ ! -f "$hook_file" ]; then
        echo -e "${YELLOW}⚠️  SKIP${NC}: $hook_name (file not found)"
        return
    fi

    echo "Testing: $hook_name"

    local total_ms=0
    local min_ms=999999
    local max_ms=0

    # Run hook multiple times and measure
    for i in $(seq 1 $ITERATIONS); do
        # Measure execution time in milliseconds
        local start=$(python3 -c 'import time; print(int(time.time() * 1000))')

        # Run the hook (suppress output, capture errors)
        if bash "$hook_file" >/dev/null 2>&1; then
            local end=$(python3 -c 'import time; print(int(time.time() * 1000))')
            local duration=$((end - start))

            total_ms=$((total_ms + duration))

            if [ $duration -lt $min_ms ]; then
                min_ms=$duration
            fi

            if [ $duration -gt $max_ms ]; then
                max_ms=$duration
            fi
        else
            echo -e "  ${YELLOW}Warning: Hook failed on iteration $i${NC}"
        fi
    done

    # Calculate average
    local avg_ms=$((total_ms / ITERATIONS))

    # Report results
    echo "  Iterations: $ITERATIONS"
    echo "  Average: ${avg_ms}ms"
    echo "  Min: ${min_ms}ms"
    echo "  Max: ${max_ms}ms"

    # Check if meets performance target
    if [ $avg_ms -le $MAX_AVG_MS ]; then
        echo -e "  ${GREEN}✅ PASS${NC}: Average ${avg_ms}ms <= ${MAX_AVG_MS}ms target"
    else
        echo -e "  ${RED}❌ FAIL${NC}: Average ${avg_ms}ms > ${MAX_AVG_MS}ms target"
        EXIT_CODE=1
    fi

    echo ""
}

# Test all hooks
test_hook_performance "$HOOKS_DIR/stop_hook.sh"
test_hook_performance "$HOOKS_DIR/sessionend_hook.sh"
test_hook_performance "$HOOKS_DIR/sessionstart_hook.sh"

# Summary
echo "=== Performance Test Summary ==="
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ All hooks meet performance target (<${MAX_AVG_MS}ms)${NC}"
else
    echo -e "${RED}❌ Some hooks exceed performance target${NC}"
    echo "Hooks must execute in <${MAX_AVG_MS}ms to avoid slowing Claude Code"
fi

exit $EXIT_CODE
