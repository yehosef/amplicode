#!/bin/bash
# test_macos_setup.sh - Verify prerequisites on macOS M1
# Checks all requirements for Amplicode plugin to work correctly

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

echo "=== macOS M1 Setup Verification ==="
echo ""

EXIT_CODE=0

# Test 1: Python version
echo -n "Python 3.11+: "
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

    if [ "$PYTHON_MAJOR" -ge 3 ] && [ "$PYTHON_MINOR" -ge 11 ]; then
        echo -e "${GREEN}✅ Python $PYTHON_VERSION${NC}"
    else
        echo -e "${RED}❌ Python $PYTHON_VERSION (need 3.11+)${NC}"
        echo "   Install: brew install python@3.11"
        EXIT_CODE=1
    fi
else
    echo -e "${RED}❌ Python not found${NC}"
    echo "   Install: brew install python@3.11"
    EXIT_CODE=1
fi

# Test 2: jq (optional but recommended)
echo -n "jq (optional): "
if command -v jq &> /dev/null; then
    JQ_VERSION=$(jq --version 2>&1)
    echo -e "${GREEN}✅ $JQ_VERSION${NC}"
else
    echo -e "${YELLOW}⚠️  Not installed (will use Python fallback)${NC}"
    echo "   Recommended: brew install jq"
fi

# Test 3: Python packages
echo -n "anthropic package: "
if python3 -c "import anthropic" 2>/dev/null; then
    ANTHROPIC_VERSION=$(python3 -c "import anthropic; print(anthropic.__version__)" 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✅ Version $ANTHROPIC_VERSION${NC}"
else
    echo -e "${RED}❌ Not installed${NC}"
    echo "   Install: pip3 install anthropic"
    EXIT_CODE=1
fi

echo -n "psutil package: "
if python3 -c "import psutil" 2>/dev/null; then
    PSUTIL_VERSION=$(python3 -c "import psutil; print(psutil.__version__)" 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✅ Version $PSUTIL_VERSION${NC}"
else
    echo -e "${RED}❌ Not installed${NC}"
    echo "   Install: pip3 install psutil"
    EXIT_CODE=1
fi

# Test 4: File locking (fcntl)
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
else
    echo -e "${RED}❌ Failed${NC}"
    echo "   File locking is required for data safety"
    EXIT_CODE=1
fi

# Test 5: ~/.claude/ directory permissions
echo -n "~/.claude/ directory: "
CLAUDE_DIR="${HOME}/.claude"

if [ -d "$CLAUDE_DIR" ]; then
    # Check permissions (should be 700 or 755)
    PERMS=$(stat -f "%Lp" "$CLAUDE_DIR" 2>/dev/null || echo "unknown")

    if [ -w "$CLAUDE_DIR" ] && [ -r "$CLAUDE_DIR" ]; then
        echo -e "${GREEN}✅ Exists and writable (${PERMS})${NC}"
    else
        echo -e "${YELLOW}⚠️  Exists but permissions issue (${PERMS})${NC}"
        echo "   Fix: chmod 700 ~/.claude"
    fi
else
    echo -e "${YELLOW}⚠️  Does not exist (will be created automatically)${NC}"
    # Try to create it
    if mkdir -p "$CLAUDE_DIR" 2>/dev/null; then
        chmod 700 "$CLAUDE_DIR"
        echo -e "   ${GREEN}✅ Created with correct permissions${NC}"
    else
        echo -e "${RED}❌ Cannot create directory${NC}"
        EXIT_CODE=1
    fi
fi

# Test 6: Temporary file access
echo -n "/tmp/ access: "
TEST_FILE="/tmp/claude_test_$$"
if touch "$TEST_FILE" 2>/dev/null && rm "$TEST_FILE" 2>/dev/null; then
    echo -e "${GREEN}✅ Can write to /tmp/${NC}"
else
    echo -e "${RED}❌ Cannot write to /tmp/${NC}"
    echo "   Required for lock files"
    EXIT_CODE=1
fi

# Test 7: Process spawning
echo -n "Process spawning: "
if python3 << 'EOF' 2>/dev/null
import subprocess
import time
proc = subprocess.Popen(['sleep', '0.1'])
proc.wait()
EOF
then
    echo -e "${GREEN}✅ Can spawn subprocesses${NC}"
else
    echo -e "${RED}❌ Cannot spawn subprocesses${NC}"
    EXIT_CODE=1
fi

# Test 8: Date command (for timestamps)
echo -n "Date command: "
if TIMESTAMP=$(date +%s 2>/dev/null); then
    echo -e "${GREEN}✅ Working (timestamp: $TIMESTAMP)${NC}"
else
    echo -e "${RED}❌ Date command failed${NC}"
    EXIT_CODE=1
fi

# Test 9: Bash version
echo -n "Bash version: "
BASH_VERSION_NUM=$(bash --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
echo -e "${GREEN}✅ Bash $BASH_VERSION_NUM${NC}"

# Test 10: flock command
echo -n "flock command: "
if command -v flock &> /dev/null; then
    echo -e "${GREEN}✅ Available${NC}"
else
    echo -e "${RED}❌ Not found${NC}"
    echo "   Install: brew install util-linux"
    EXIT_CODE=1
fi

echo ""
echo "=== Setup Summary ==="

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ All prerequisites met - Amplicode ready to run${NC}"
else
    echo -e "${RED}❌ Some prerequisites missing - see errors above${NC}"
    echo ""
    echo "Quick fix commands:"
    echo "  brew install python@3.11 jq util-linux"
    echo "  pip3 install anthropic psutil"
fi

exit $EXIT_CODE
