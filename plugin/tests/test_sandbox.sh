#!/bin/bash
# test_sandbox.sh - Test sandbox mode compatibility
# Tests what functionality works in Claude Code sandbox mode
# Helps determine graceful degradation strategy

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if colors are supported
if [ ! -t 1 ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

echo "=== Sandbox Mode Compatibility Test ==="
echo ""

# Detect if running in sandbox mode
if [ -n "${CLAUDE_SANDBOX_MODE:-}" ]; then
    echo -e "${YELLOW}⚠️  Running in SANDBOX MODE${NC}"
    SANDBOX_DETECTED=true
else
    echo -e "${BLUE}ℹ️  Running in NORMAL MODE${NC}"
    echo "   (Set CLAUDE_SANDBOX_MODE=1 to test sandbox behavior)"
    SANDBOX_DETECTED=false
fi

echo ""
echo "=== Capability Tests ==="

TEST_PASSED=0
TEST_FAILED=0
TEST_WARNINGS=0

# Test 1: Write to .data/ directory
echo -n "Write to .data/: "
if mkdir -p .data 2>/dev/null && echo "test" > .data/test.txt 2>/dev/null && [ -f .data/test.txt ]; then
    echo -e "${GREEN}✅ Can write${NC}"
    TEST_PASSED=$((TEST_PASSED + 1))
    rm -f .data/test.txt
else
    echo -e "${RED}❌ Cannot write${NC}"
    echo "   Impact: Cannot store memory.json locally"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 2: Write to ~/.claude/
echo -n "Write to ~/.claude/: "
CLAUDE_DIR="${HOME}/.claude"
if mkdir -p "$CLAUDE_DIR" 2>/dev/null && echo "test" > "$CLAUDE_DIR/test.txt" 2>/dev/null && [ -f "$CLAUDE_DIR/test.txt" ]; then
    echo -e "${GREEN}✅ Can write${NC}"
    TEST_PASSED=$((TEST_PASSED + 1))
    rm -f "$CLAUDE_DIR/test.txt"
else
    echo -e "${RED}❌ Cannot write${NC}"
    echo "   Impact: Cannot store global queue and worker files"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 3: Write to /tmp/
echo -n "Write to /tmp/: "
TEST_FILE="/tmp/claude_sandbox_test_$$"
if echo "test" > "$TEST_FILE" 2>/dev/null && [ -f "$TEST_FILE" ]; then
    echo -e "${GREEN}✅ Can write${NC}"
    TEST_PASSED=$((TEST_PASSED + 1))
    rm -f "$TEST_FILE"
else
    echo -e "${RED}❌ Cannot write${NC}"
    echo "   Impact: Cannot use lock files"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 4: Spawn subprocess
echo -n "Spawn subprocess: "
if python3 -c "import subprocess; subprocess.Popen(['sleep', '0.1']).wait()" 2>/dev/null; then
    echo -e "${GREEN}✅ Can spawn${NC}"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    echo -e "${RED}❌ Cannot spawn${NC}"
    echo "   Impact: Cannot start background worker"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 5: Background process persistence
echo -n "Background persistence: "
PID_FILE="/tmp/claude_bg_test_$$.pid"
python3 -c "
import subprocess
import sys
proc = subprocess.Popen(['sleep', '2'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
with open('$PID_FILE', 'w') as f:
    f.write(str(proc.pid))
" 2>/dev/null

if [ -f "$PID_FILE" ]; then
    BG_PID=$(cat "$PID_FILE")
    sleep 0.5  # Wait a bit

    if ps -p "$BG_PID" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Persists${NC}"
        TEST_PASSED=$((TEST_PASSED + 1))
        kill "$BG_PID" 2>/dev/null || true
    else
        echo -e "${RED}❌ Killed after parent exits${NC}"
        echo "   Impact: Background worker won't survive hook exit"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
    rm -f "$PID_FILE"
else
    echo -e "${RED}❌ Cannot test${NC}"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 6: File locking
echo -n "File locking (fcntl): "
if python3 << 'EOF' 2>/dev/null
import fcntl
import tempfile
with tempfile.NamedTemporaryFile() as f:
    fcntl.flock(f.fileno(), fcntl.LOCK_EX)
    fcntl.flock(f.fileno(), fcntl.LOCK_UN)
EOF
then
    echo -e "${GREEN}✅ Working${NC}"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    echo -e "${RED}❌ Failed${NC}"
    echo "   Impact: Cannot ensure data safety in multi-session scenarios"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 7: flock command
echo -n "flock command: "
if command -v flock &> /dev/null; then
    # Test actual flock usage
    FLOCK_TEST="/tmp/flock_test_$$.txt"
    FLOCK_LOCK="/tmp/flock_test_$$.lock"

    if {
        flock -x 200
        echo "test" > "$FLOCK_TEST"
    } 200>"$FLOCK_LOCK" 2>/dev/null; then
        echo -e "${GREEN}✅ Working${NC}"
        TEST_PASSED=$((TEST_PASSED + 1))
        rm -f "$FLOCK_TEST" "$FLOCK_LOCK"
    else
        echo -e "${RED}❌ Cannot acquire locks${NC}"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
else
    echo -e "${RED}❌ Command not found${NC}"
    echo "   Impact: Hooks cannot use flock for queue safety"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 8: Network access
echo -n "Network access: "
if python3 << 'EOF' 2>/dev/null
import urllib.request
import socket
try:
    response = urllib.request.urlopen('https://www.google.com', timeout=5)
    if response.status == 200:
        exit(0)
except:
    pass
exit(1)
EOF
then
    echo -e "${GREEN}✅ Can access network${NC}"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    echo -e "${YELLOW}⚠️  Network blocked or unavailable${NC}"
    echo "   Impact: Cannot call Anthropic API for learning"
    TEST_WARNINGS=$((TEST_WARNINGS + 1))
fi

# Test 9: Import required Python packages
echo -n "Python packages: "
MISSING_PACKAGES=""

if ! python3 -c "import anthropic" 2>/dev/null; then
    MISSING_PACKAGES="$MISSING_PACKAGES anthropic"
fi

if ! python3 -c "import psutil" 2>/dev/null; then
    MISSING_PACKAGES="$MISSING_PACKAGES psutil"
fi

if [ -z "$MISSING_PACKAGES" ]; then
    echo -e "${GREEN}✅ All required packages installed${NC}"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    echo -e "${YELLOW}⚠️  Missing:$MISSING_PACKAGES${NC}"
    echo "   Install: pip3 install$MISSING_PACKAGES"
    TEST_WARNINGS=$((TEST_WARNINGS + 1))
fi

# Test 10: Read environment variables
echo -n "Environment vars: "
if [ -n "${USER:-}" ] && [ -n "${HOME:-}" ]; then
    echo -e "${GREEN}✅ Can read USER, HOME${NC}"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    echo -e "${RED}❌ Cannot read basic env vars${NC}"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

echo ""
echo "=== Sandbox Compatibility Summary ==="
echo ""
echo "Test Results:"
echo -e "  ${GREEN}✅ Passed: $TEST_PASSED${NC}"
echo -e "  ${RED}❌ Failed: $TEST_FAILED${NC}"
echo -e "  ${YELLOW}⚠️  Warnings: $TEST_WARNINGS${NC}"
echo ""

# Determine capability level
if [ $TEST_FAILED -eq 0 ]; then
    if [ $TEST_WARNINGS -eq 0 ]; then
        echo -e "${GREEN}✅ FULL COMPATIBILITY${NC}"
        echo "   All features will work in this environment"
        EXIT_CODE=0
    else
        echo -e "${YELLOW}⚠️  PARTIAL COMPATIBILITY${NC}"
        echo "   Core features work, some optional features may be limited"
        EXIT_CODE=0
    fi
else
    echo -e "${RED}❌ LIMITED COMPATIBILITY${NC}"
    echo ""
    echo "Recommendations:"

    if [ $TEST_FAILED -ge 5 ]; then
        echo "  - Background learning will NOT work in this environment"
        echo "  - Recommend disabling plugin in sandbox mode"
        echo "  - Graceful degradation: hooks should exit early if in sandbox"
    else
        echo "  - Some features may work with degraded functionality"
        echo "  - Check specific failed tests above for impact"
    fi

    EXIT_CODE=1
fi

echo ""
echo "Graceful Degradation Strategy:"
echo "  If CLAUDE_SANDBOX_MODE is set, hooks should:"
echo "  1. Detect sandbox environment"
echo "  2. Skip background worker operations"
echo "  3. Exit cleanly without errors"
echo "  4. Log warning to user about limited functionality"

exit $EXIT_CODE
