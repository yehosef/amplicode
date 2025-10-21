#!/bin/bash
# sessionstart_hook.sh - Loads preferences and ensures worker is running
# Target: <100ms execution time (has more work to do)
# Fires: Once per session (when session starts)

set -euo pipefail

# Paths
WORKER_PATH="${HOME}/.claude/learning_worker.py"
# Get the directory of this script (works on macOS and Linux)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLUGIN_DIR="${PLUGIN_DIR:-$(dirname "$SCRIPT_DIR")}"
PLUGIN_WORKER="${PLUGIN_DIR}/scripts/learning_worker.py"
PROJECT_ROOT="${PWD}"
MEMORY_FILE="${PROJECT_ROOT}/.data/memory.json"
GLOBAL_QUEUE="${HOME}/.claude/learning_queue.jsonl"
TIMESTAMP=$(date +%s)

# Create necessary directories
mkdir -p "${HOME}/.claude"
mkdir -p "${PROJECT_ROOT}/.data"

# First-time setup: Install worker to global location
if [ ! -f "$WORKER_PATH" ]; then
    echo "📦 Installing Amplicode worker..."
    cp "$PLUGIN_WORKER" "$WORKER_PATH"
    chmod +x "$WORKER_PATH"
    echo "✅ Worker installed to ~/.claude/learning_worker.py"
fi

# Copy all supporting scripts if they don't exist
for script in learning_extractor.py learning_memory.py health_monitor.py; do
    if [ -f "${PLUGIN_DIR}/scripts/${script}" ] && [ ! -f "${HOME}/.claude/${script}" ]; then
        cp "${PLUGIN_DIR}/scripts/${script}" "${HOME}/.claude/${script}"
    fi
done

# Ensure worker is running (non-blocking check)
if ! pgrep -f "learning_worker.py" > /dev/null 2>&1; then
    echo "🚀 Starting Amplicode worker..."

    # Start worker in background with nohup
    nohup python3 "$WORKER_PATH" > "${HOME}/.claude/worker.log" 2>&1 &
    WORKER_PID=$!

    echo "✅ Worker started (PID: $WORKER_PID)"
    echo "$WORKER_PID" > "${HOME}/.claude/learning_worker.pid"

    # Give it a moment to initialize
    sleep 0.5
fi

# Queue session_start event (compact, single-line for JSONL format)
if command -v jq &> /dev/null; then
    EVENT_JSON=$(jq -c -n \
        --arg project "$PROJECT_ROOT" \
        --arg timestamp "$TIMESTAMP" \
        --arg event "session_start" \
        '{
            project: $project,
            event_type: $event,
            timestamp: ($timestamp | tonumber)
        }')
else
    EVENT_JSON=$(python3 -c "
import json
print(json.dumps({
    'project': '$PROJECT_ROOT',
    'event_type': 'session_start',
    'timestamp': $TIMESTAMP
}, separators=(',', ':')))
")
fi

# Atomic append with file lock (using Python for macOS compatibility)
python3 << EOF
import fcntl
import os

queue_file = "$GLOBAL_QUEUE"
event_json = """$EVENT_JSON"""

os.makedirs(os.path.dirname(queue_file), exist_ok=True)

lock_file = "/tmp/claude_learning_queue.lock"
with open(lock_file, 'w') as lock:
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
    with open(queue_file, 'a') as f:
        f.write(event_json + '\\n')
    fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
EOF

# Load preferences if they exist (for display to user)
if [ -f "$MEMORY_FILE" ]; then
    PREF_COUNT=$(python3 -c "
import json
try:
    with open('$MEMORY_FILE') as f:
        data = json.load(f)
        print(len(data.get('preferences', [])))
except:
    print(0)
" 2>/dev/null || echo "0")

    if [ "$PREF_COUNT" -gt 0 ]; then
        echo "🧠 Loaded $PREF_COUNT learned preference(s) for this project"
    fi
fi

exit 0
