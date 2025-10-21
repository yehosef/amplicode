# Amplicode Status

Shows the health and status of the Amplicode background learning worker.

```bash
#!/bin/bash
set -euo pipefail

# File paths
HEARTBEAT_FILE="${HOME}/.claude/worker_heartbeat.json"
QUEUE_FILE="${HOME}/.claude/learning_queue.jsonl"
PID_FILE="${HOME}/.claude/learning_worker.pid"

echo "🔍 Amplicode Worker Status"
echo ""

# Check if worker PID file exists
if [ ! -f "$PID_FILE" ]; then
    echo "🔴 Worker not running"
    echo ""
    echo "   No PID file found at: $PID_FILE"
    echo ""
    echo "💡 Start the worker with: /amplicode-restart"
    exit 0
fi

# Read PID
WORKER_PID=$(cat "$PID_FILE" 2>/dev/null || echo "")

# Check if process is actually running
if [ -z "$WORKER_PID" ] || ! ps -p "$WORKER_PID" > /dev/null 2>&1; then
    echo "🔴 Worker stopped"
    echo ""
    echo "   PID file exists but process not running"
    echo "   Last PID: ${WORKER_PID:-unknown}"
    echo ""
    echo "💡 Restart the worker with: /amplicode-restart"
    exit 0
fi

# Check heartbeat
if [ ! -f "$HEARTBEAT_FILE" ]; then
    echo "⚠️  Worker running but no heartbeat"
    echo ""
    echo "   PID: $WORKER_PID"
    echo "   No heartbeat file found"
    echo ""
    echo "💡 Worker may be initializing or stuck. Wait 10s or restart with: /amplicode-restart"
    exit 0
fi

# Parse heartbeat (using Python for JSON parsing)
HEARTBEAT_INFO=$(python3 <<EOF
import json
import time
from datetime import datetime

try:
    with open("$HEARTBEAT_FILE") as f:
        hb = json.load(f)

    timestamp = hb.get("timestamp", 0)
    status = hb.get("status", "unknown")
    processed = hb.get("events_processed", 0)
    current_event = hb.get("current_event", None)

    # Calculate time since last heartbeat
    now = time.time()
    seconds_ago = int(now - timestamp)

    # Determine health status
    if seconds_ago > 30:
        health = "STUCK"
        emoji = "🔴"
    elif seconds_ago > 10:
        health = "degraded"
        emoji = "⚠️"
    else:
        health = "healthy"
        emoji = "🟢"

    # Format output
    print(f"{emoji}|{health}|{seconds_ago}|{status}|{processed}")

except Exception as e:
    print(f"❌|error|0|unknown|0")

EOF
)

# Parse the output
IFS='|' read -r EMOJI HEALTH SECONDS_AGO STATUS PROCESSED <<< "$HEARTBEAT_INFO"

# Get queue size
QUEUE_SIZE=0
if [ -f "$QUEUE_FILE" ]; then
    QUEUE_SIZE=$(wc -l < "$QUEUE_FILE" | tr -d ' ')
fi

# Display status
echo "$EMOJI Worker $HEALTH"
echo ""
echo "   PID: $WORKER_PID"
echo "   Status: $STATUS"
echo "   Queue size: $QUEUE_SIZE events"
echo "   Processed: $PROCESSED events (this session)"
echo "   Last heartbeat: ${SECONDS_AGO}s ago"
echo ""

# Health recommendations
if [ "$HEALTH" == "STUCK" ]; then
    echo "⚠️  Worker appears stuck (no heartbeat for ${SECONDS_AGO}s)"
    echo "💡 Force restart with: /amplicode-restart --force"
elif [ "$HEALTH" == "degraded" ]; then
    echo "⚠️  Worker responding slowly"
    echo "💡 Check logs with: /amplicode-logs --level=ERROR"
elif [ "$QUEUE_SIZE" -gt 100 ]; then
    echo "⚠️  Queue is growing (${QUEUE_SIZE} events)"
    echo "💡 Worker may be processing slowly. Check logs: /amplicode-logs"
else
    echo "✅ Worker operating normally"
fi

echo ""
echo "📊 Files:"
echo "   Heartbeat: $HEARTBEAT_FILE"
echo "   Queue: $QUEUE_FILE"
echo "   PID: $PID_FILE"
```
