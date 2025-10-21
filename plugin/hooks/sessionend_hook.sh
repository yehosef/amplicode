#!/bin/bash
# sessionend_hook.sh - Queues session summary for background analysis
# Target: <20ms execution time
# Fires: Once per session (when session ends)

set -euo pipefail

# Paths
GLOBAL_QUEUE="${HOME}/.claude/learning_queue.jsonl"
PROJECT_ROOT="${PWD}"
TIMESTAMP=$(date +%s)

# Create queue if doesn't exist
mkdir -p "$(dirname "$GLOBAL_QUEUE")"
touch "$GLOBAL_QUEUE"

# Generate JSON event for session end (compact, single-line for JSONL format)
if command -v jq &> /dev/null; then
    EVENT_JSON=$(jq -c -n \
        --arg project "$PROJECT_ROOT" \
        --arg timestamp "$TIMESTAMP" \
        --arg event "session_end" \
        '{
            project: $project,
            event_type: $event,
            timestamp: ($timestamp | tonumber),
            context: {
                user: env.USER,
                pwd: env.PWD
            }
        }')
else
    EVENT_JSON=$(python3 -c "
import json
import os
print(json.dumps({
    'project': '$PROJECT_ROOT',
    'event_type': 'session_end',
    'timestamp': $TIMESTAMP,
    'context': {
        'user': os.environ.get('USER', 'unknown'),
        'pwd': os.environ.get('PWD', '$PROJECT_ROOT')
    }
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

exit 0
