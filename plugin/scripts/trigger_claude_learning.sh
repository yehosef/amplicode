#!/bin/bash
# trigger_claude_learning.sh - Automatically trigger Claude Code to process learning
# Called by worker when queue reaches threshold

set -euo pipefail

PROJECT_DIR="$1"
COMMAND="${2:-/amplicode-process}"

echo "🤖 Triggering Claude Code to process learning..."
echo "   Project: $PROJECT_DIR"
echo "   Command: $COMMAND"

# Method 1: AppleScript to send command to Claude Code (macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    osascript <<EOF
tell application "Claude"
    activate
    delay 0.5

    -- Send the slash command
    tell application "System Events"
        keystroke "$COMMAND"
        delay 0.3
        key code 36  -- Enter key
    end tell
end tell
EOF

    echo "✅ Sent command to Claude Code via AppleScript"
    exit 0
fi

# Method 2: Create pending_learning.md and notify (fallback)
echo "⚠️  AppleScript not available, creating pending learning file..."
LEARNING_FILE="$PROJECT_DIR/.claude/pending_learning.md"

cat > "$LEARNING_FILE" << 'LEARNING_EOF'
# 🧠 Amplicode Auto-Learning Task (Triggered by Worker)

**The background worker detected queued events and triggered this analysis.**

## Your Task

Analyze your conversation history and extract preferences from corrections.

### Step 1: Read the Queue

```bash
cat ~/.claude/learning_queue.jsonl
```

### Step 2: Analyze for Corrections

Look back at the conversation for when user:
- Rejected your suggestion: "No, use X instead"
- Corrected your approach: "Actually, prefer Y"
- Specified an alternative: "Use this, not that"

### Step 3: Update Memory

For each correction found, update `.data/memory.json`:

```json
{
  "preferences": [
    {
      "type": "prefer",
      "subject": "what was preferred",
      "context": "exact user quote",
      "scope": "project|language|global",
      "confidence": 0.9,
      "learned_at": "ISO timestamp"
    }
  ]
}
```

### Step 4: Clean Up

After processing:
1. Clear queue: `> ~/.claude/learning_queue.jsonl`
2. Delete this file: `rm .claude/pending_learning.md`

**Process now if corrections found. Otherwise just delete this file.**
LEARNING_EOF

echo "✅ Created $LEARNING_FILE"
echo "   Claude Code will see this when you open the project"

exit 0
