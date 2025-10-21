#!/bin/bash
# stop_hook.sh - Detects potential corrections and queues for background learning
# Target: <20ms execution time
# Fires: 50-100 times per session (after every Claude response)

set -euo pipefail

# Paths
GLOBAL_QUEUE="${HOME}/.claude/learning_queue.jsonl"
PROJECT_ROOT="${PWD}"
TIMESTAMP=$(date +%s)

# Create queue if doesn't exist
mkdir -p "$(dirname "$GLOBAL_QUEUE")"
touch "$GLOBAL_QUEUE"

# Generate JSON event (compact, single-line for JSONL format)
# Use jq if available (fastest), fallback to Python
if command -v jq &> /dev/null; then
    EVENT_JSON=$(jq -c -n \
        --arg project "$PROJECT_ROOT" \
        --arg timestamp "$TIMESTAMP" \
        --arg event "stop" \
        '{
            project: $project,
            event_type: $event,
            timestamp: ($timestamp | tonumber),
            context: {
                user: env.USER,
                shell: env.SHELL
            }
        }')
else
    # Fallback to Python (slower but works everywhere)
    EVENT_JSON=$(python3 -c "
import json
import os
print(json.dumps({
    'project': '$PROJECT_ROOT',
    'event_type': 'stop',
    'timestamp': $TIMESTAMP,
    'context': {
        'user': os.environ.get('USER', 'unknown'),
        'shell': os.environ.get('SHELL', 'unknown')
    }
}, separators=(',', ':')))
")
fi

# Atomic append with file lock
# macOS doesn't have flock by default, use Python for atomic append with locking
python3 << EOF
import fcntl
import os

queue_file = "$GLOBAL_QUEUE"
event_json = """$EVENT_JSON"""

# Ensure directory exists
os.makedirs(os.path.dirname(queue_file), exist_ok=True)

# Atomic append with file locking
lock_file = "/tmp/claude_learning_queue.lock"
with open(lock_file, 'w') as lock:
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
    with open(queue_file, 'a') as f:
        f.write(event_json + '\\n')
    fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
EOF

# Exit successfully (no output to avoid cluttering Claude Code)
exit 0
