# Amplicode Logs

View worker logs with filtering options.

```bash
#!/bin/bash
set -euo pipefail

# File paths
LOG_FILE="${HOME}/.claude/worker.log"

# Parse arguments
LINES=50
FOLLOW=false
LEVEL=""

for arg in "$@"; do
    case $arg in
        --lines=*)
            LINES="${arg#*=}"
            ;;
        --follow)
            FOLLOW=true
            ;;
        --level=*)
            LEVEL="${arg#*=}"
            ;;
    esac
done

# Check if log file exists
if [ ! -f "$LOG_FILE" ]; then
    echo "📋 No worker logs found"
    echo ""
    echo "   Log file: $LOG_FILE"
    echo "   Worker may not have started yet"
    echo ""
    echo "💡 Check worker status with: /amplicode-status"
    exit 0
fi

# Display header
echo "📋 Amplicode Worker Logs"
echo ""
echo "   File: $LOG_FILE"
if [ -n "$LEVEL" ]; then
    echo "   Filter: $LEVEL level only"
fi
if [ "$FOLLOW" = true ]; then
    echo "   Mode: Following (press Ctrl+C to stop)"
else
    echo "   Showing: Last $LINES lines"
fi
echo ""
echo "────────────────────────────────────────────────────────────────"
echo ""

# Function to colorize log levels
colorize_logs() {
    while IFS= read -r line; do
        if [[ "$line" =~ \[ERROR\] ]]; then
            echo -e "\033[0;31m$line\033[0m"  # Red
        elif [[ "$line" =~ \[WARN\] ]]; then
            echo -e "\033[0;33m$line\033[0m"  # Yellow
        elif [[ "$line" =~ \[INFO\] ]]; then
            echo -e "\033[0;36m$line\033[0m"  # Cyan
        elif [[ "$line" =~ \[DEBUG\] ]]; then
            echo -e "\033[0;37m$line\033[0m"  # Gray
        else
            echo "$line"
        fi
    done
}

# Build the command
if [ "$FOLLOW" = true ]; then
    # Follow mode
    if [ -n "$LEVEL" ]; then
        tail -f "$LOG_FILE" | grep --line-buffered "\[$LEVEL\]" | colorize_logs
    else
        tail -f "$LOG_FILE" | colorize_logs
    fi
else
    # Static mode
    if [ -n "$LEVEL" ]; then
        grep "\[$LEVEL\]" "$LOG_FILE" | tail -n "$LINES" | colorize_logs
    else
        tail -n "$LINES" "$LOG_FILE" | colorize_logs
    fi
fi

echo ""
echo "────────────────────────────────────────────────────────────────"
echo ""

# Show usage hints
if [ "$FOLLOW" = false ]; then
    echo "💡 Options:"
    echo "   --lines=N      Show N lines (default: 50)"
    echo "   --follow       Follow logs in real-time"
    echo "   --level=LEVEL  Filter by level (ERROR, WARN, INFO, DEBUG)"
    echo ""
    echo "Examples:"
    echo "   /amplicode-logs --lines=100"
    echo "   /amplicode-logs --level=ERROR"
    echo "   /amplicode-logs --follow"
fi
```
