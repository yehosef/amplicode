# Amplicode Restart

Restart the Amplicode background learning worker.

```bash
#!/bin/bash
set -euo pipefail

# File paths
PID_FILE="${HOME}/.claude/learning_worker.pid"
WORKER_SCRIPT="${HOME}/.claude/learning_worker.py"
LOG_FILE="${HOME}/.claude/worker.log"
HEARTBEAT_FILE="${HOME}/.claude/worker_heartbeat.json"

# Parse arguments
FORCE=false
for arg in "$@"; do
    case $arg in
        --force)
            FORCE=true
            ;;
    esac
done

echo "🔄 Restarting Amplicode Worker"
echo ""

# ========================================
# STEP 1: Show current status
# ========================================
echo "📊 Current status:"

if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null || echo "")

    if [ -n "$OLD_PID" ] && ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "   🟢 Worker running (PID $OLD_PID)"

        # Check heartbeat age
        if [ -f "$HEARTBEAT_FILE" ]; then
            HEARTBEAT_AGE=$(python3 <<EOF
import json
import time
try:
    with open("$HEARTBEAT_FILE") as f:
        hb = json.load(f)
    print(int(time.time() - hb.get("timestamp", 0)))
except:
    print("unknown")
EOF
)
            echo "   Last heartbeat: ${HEARTBEAT_AGE}s ago"
        fi
    else
        echo "   🔴 Worker stopped (stale PID: $OLD_PID)"
    fi
else
    echo "   🔴 Worker not running (no PID file)"
fi

echo ""

# ========================================
# STEP 2: Stop existing worker
# ========================================
echo "🛑 Stopping worker..."

if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null || echo "")

    if [ -n "$OLD_PID" ] && ps -p "$OLD_PID" > /dev/null 2>&1; then
        if [ "$FORCE" = true ]; then
            echo "   Force killing PID $OLD_PID (SIGKILL)..."
            kill -9 "$OLD_PID" 2>/dev/null || true
        else
            echo "   Stopping PID $OLD_PID gracefully (SIGTERM)..."
            kill "$OLD_PID" 2>/dev/null || true

            # Wait up to 5 seconds for graceful shutdown
            for i in {1..5}; do
                if ! ps -p "$OLD_PID" > /dev/null 2>&1; then
                    break
                fi
                sleep 1
            done

            # Force kill if still running
            if ps -p "$OLD_PID" > /dev/null 2>&1; then
                echo "   Worker didn't stop gracefully, force killing..."
                kill -9 "$OLD_PID" 2>/dev/null || true
            fi
        fi

        # Verify stopped
        sleep 1
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            echo "   ❌ Failed to stop worker (PID $OLD_PID still running)"
            echo ""
            echo "💡 Try: /amplicode-restart --force"
            exit 1
        else
            echo "   ✅ Worker stopped"
        fi
    else
        echo "   Worker already stopped"
    fi

    # Clean up PID file
    rm -f "$PID_FILE"
else
    echo "   No worker to stop"
fi

echo ""

# ========================================
# STEP 3: Check worker script exists
# ========================================
if [ ! -f "$WORKER_SCRIPT" ]; then
    echo "❌ Worker script not found: $WORKER_SCRIPT"
    echo ""
    echo "💡 The worker should be installed automatically on SessionStart."
    echo "   Please open a new Claude Code session to trigger installation."
    exit 1
fi

if [ ! -x "$WORKER_SCRIPT" ]; then
    echo "🔧 Making worker executable..."
    chmod +x "$WORKER_SCRIPT"
fi

# ========================================
# STEP 4: Start new worker
# ========================================
echo "▶️  Starting worker..."

# Start worker in background with nohup
nohup "$WORKER_SCRIPT" > "$LOG_FILE" 2>&1 &
NEW_PID=$!

# Save PID
echo "$NEW_PID" > "$PID_FILE"

# Wait a moment for worker to initialize
sleep 2

# Verify worker started
if ps -p "$NEW_PID" > /dev/null 2>&1; then
    echo "   ✅ Worker started (PID $NEW_PID)"

    # Wait for first heartbeat (up to 5 seconds)
    echo "   Waiting for heartbeat..."
    for i in {1..5}; do
        if [ -f "$HEARTBEAT_FILE" ]; then
            # Check if heartbeat is recent (within last 3 seconds)
            HEARTBEAT_FRESH=$(python3 <<EOF
import json
import time
try:
    with open("$HEARTBEAT_FILE") as f:
        hb = json.load(f)
    is_fresh = (time.time() - hb.get("timestamp", 0)) < 3
    print("true" if is_fresh else "false")
except:
    print("false")
EOF
)
            if [ "$HEARTBEAT_FRESH" = "true" ]; then
                echo "   ✅ Heartbeat detected"
                break
            fi
        fi
        sleep 1
    done

    echo ""
    echo "🟢 Worker restarted successfully"
    echo ""
    echo "📊 New status:"
    echo "   PID: $NEW_PID"
    echo "   Log: $LOG_FILE"
    echo ""
    echo "💡 Check status with: /amplicode-status"
    echo "💡 View logs with: /amplicode-logs"

else
    echo "   ❌ Worker failed to start"
    echo ""
    echo "💡 Check logs for errors:"
    echo "   /amplicode-logs --lines=20"
    exit 1
fi
```
