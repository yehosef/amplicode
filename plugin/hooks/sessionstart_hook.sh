#!/bin/bash
# sessionstart_hook.sh - Loads preferences and ensures worker is running
# Target: <100ms execution time (has more work to do)
# Fires: Once per session (when session starts)

set -euo pipefail

# Paths
MONITOR_PATH="${HOME}/.claude/learning_monitor.py"
TRIGGER_SCRIPT_PATH="${HOME}/.claude/trigger_claude_learning.sh"
# Get the directory of this script (works on macOS and Linux)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLUGIN_DIR="${PLUGIN_DIR:-$(dirname "$SCRIPT_DIR")}"
PLUGIN_MONITOR="${PLUGIN_DIR}/scripts/learning_monitor.py"
PLUGIN_TRIGGER="${PLUGIN_DIR}/scripts/trigger_claude_learning.sh"
PROJECT_ROOT="${PWD}"
MEMORY_FILE="${PROJECT_ROOT}/.data/memory.json"
GLOBAL_QUEUE="${HOME}/.claude/learning_queue.jsonl"
TIMESTAMP=$(date +%s)

# Create necessary directories
mkdir -p "${HOME}/.claude"
mkdir -p "${PROJECT_ROOT}/.data"

# First-time setup: Install monitor and trigger script to global location
if [ ! -f "$MONITOR_PATH" ]; then
    echo "📦 Installing Amplicode monitor..."
    cp "$PLUGIN_MONITOR" "$MONITOR_PATH"
    chmod +x "$MONITOR_PATH"
    echo "✅ Monitor installed to ~/.claude/learning_monitor.py"
fi

if [ ! -f "$TRIGGER_SCRIPT_PATH" ]; then
    cp "$PLUGIN_TRIGGER" "$TRIGGER_SCRIPT_PATH"
    chmod +x "$TRIGGER_SCRIPT_PATH"
fi

# Copy all supporting scripts if they don't exist
for script in learning_extractor.py learning_memory.py health_monitor.py; do
    if [ -f "${PLUGIN_DIR}/scripts/${script}" ] && [ ! -f "${HOME}/.claude/${script}" ]; then
        cp "${PLUGIN_DIR}/scripts/${script}" "${HOME}/.claude/${script}"
    fi
done

# Ensure monitor is running (non-blocking check)
if ! pgrep -f "learning_monitor.py" > /dev/null 2>&1; then
    echo "🚀 Starting Amplicode monitor..."

    # Start monitor in background with nohup
    nohup python3 "$MONITOR_PATH" > "${HOME}/.claude/monitor.log" 2>&1 &
    MONITOR_PID=$!

    echo "✅ Monitor started (PID: $MONITOR_PID)"
    echo "   Will automatically trigger Claude Code when queue reaches 10 events"
    echo "$MONITOR_PID" > "${HOME}/.claude/learning_monitor.pid"

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

# Auto-learning: Check if there are queued events to process
LEARNING_PROMPT="${PROJECT_ROOT}/.claude/pending_learning.md"

if [ -f "$GLOBAL_QUEUE" ] && [ -s "$GLOBAL_QUEUE" ]; then
    QUEUE_SIZE=$(wc -l < "$GLOBAL_QUEUE" 2>/dev/null || echo "0")

    if [ "$QUEUE_SIZE" -gt 0 ]; then
        # Create learning prompt that Claude will see in context
        cat > "$LEARNING_PROMPT" << 'LEARNING_EOF'
# 🧠 Amplicode Auto-Learning Task

**You have queued learning events to process from previous sessions.**

## Your Task

Analyze your conversation history and extract preferences from corrections.

### What is a correction?

A correction is when the user:
- Rejected your suggestion and specified an alternative
- Said "No, use X instead"
- Said "Actually, prefer Y"
- Corrected your approach

### Examples

```
❌ Not a correction:
User: "Can you add auth?"
Claude: "I'll use JWT"
User: "Sounds good"

✅ IS a correction:
User: "Can you add auth?"
Claude: "I'll use JWT with Redis for sessions"
User: "No, use local file-based sessions instead"
     ↑ CORRECTION - user rejected Redis, prefers files
```

### Step 1: Read the Queue

Read the queue file to see how many events there are:

```bash
cat ~/.claude/learning_queue.jsonl
```

### Step 2: Analyze Conversation History

Look back at the conversation for corrections. For each correction, extract:
- What was rejected
- What was preferred
- Why (if stated)
- Is it project-specific or general?

### Step 3: Update Memory

If you found corrections, update `.data/memory.json` with this structure:

```json
{
  "preferences": [
    {
      "type": "prefer",
      "subject": "local files over Redis for sessions",
      "context": "User said: 'No, use local file-based sessions instead'",
      "scope": "project",
      "confidence": 0.95,
      "learned_at": "2025-10-22T02:30:00"
    }
  ],
  "version": "1.0",
  "updated_at": "2025-10-22T02:30:00"
}
```

**Scopes:**
- `"project"` - Specific to this codebase (e.g., "this legacy project uses X")
- `"language"` - Applies to all projects in this language (e.g., "use pytest in Python")
- `"global"` - Applies everywhere (e.g., "always use descriptive names")

### Step 4: Clear Queue and This File

After processing:
1. Clear the queue: `> ~/.claude/learning_queue.jsonl`
2. Delete this prompt: `rm .claude/pending_learning.md`

---

**Please process now if you found any corrections. If no corrections found, just delete this file.**
LEARNING_EOF

        echo "🧠 Auto-learning enabled - Claude will analyze $QUEUE_SIZE event(s)"
    fi
fi

# Load existing preferences if they exist (for display to user)
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
        echo "✅ Loaded $PREF_COUNT learned preference(s) for this project"
    fi
fi

exit 0
