# Process Learning Queue

Analyzes queued events and extracts preferences using Claude Code itself.

**How it works:**
1. Reads queued events from `~/.claude/learning_queue.jsonl`
2. Claude analyzes corrections and extracts preferences
3. Writes learned preferences to `.data/memory.json`
4. Archives processed events

**Why this approach:**
- Uses your existing Claude Pro subscription ($200/month)
- No extra API costs
- More transparent - you see what Claude learns
- You control when processing happens

---

```bash
#!/bin/bash
set -euo pipefail

PROJECT_ROOT="${PWD}"
QUEUE_FILE="${HOME}/.claude/learning_queue.jsonl"
MEMORY_FILE="${PROJECT_ROOT}/.data/memory.json"
ARCHIVE_FILE="${HOME}/.claude/learning_queue_archive.jsonl"

# Check if queue exists and has events
if [ ! -f "$QUEUE_FILE" ]; then
    echo "📭 No queued events to process"
    exit 0
fi

QUEUE_SIZE=$(wc -l < "$QUEUE_FILE" 2>/dev/null || echo "0")
if [ "$QUEUE_SIZE" -eq 0 ]; then
    echo "📭 Queue is empty"
    exit 0
fi

echo "📊 Found $QUEUE_SIZE queued events"
echo ""

# Read the queue and prepare for analysis
EVENTS=$(cat "$QUEUE_FILE")

# Archive the queue (we'll process it now)
cat "$QUEUE_FILE" >> "$ARCHIVE_FILE"
> "$QUEUE_FILE"  # Clear queue

echo "🔍 Analyzing events for corrections and preferences..."
echo ""
echo "Please analyze the following events and extract any preferences:"
echo ""
```

```python
import json
import sys
from pathlib import Path

# Read events
events_file = Path.home() / '.claude' / 'learning_queue_archive.jsonl'
events = []

try:
    with open(events_file, 'r') as f:
        for line in f:
            if line.strip():
                try:
                    events.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
except FileNotFoundError:
    print("No events found")
    sys.exit(0)

# Show events to Claude for analysis
print(f"📋 **Events to analyze ({len(events)} total):**")
print("")

for i, event in enumerate(events[-20:], 1):  # Show last 20
    event_type = event.get('event_type', 'unknown')
    project = event.get('project', 'unknown')
    timestamp = event.get('timestamp', 0)

    print(f"{i}. **{event_type}** in {project}")

print("")
print("---")
print("")
print("**Your task:**")
print("")
print("1. Look back at the conversation history for corrections")
print("2. A correction is when the user rejected your suggestion and specified what they prefer")
print("3. Examples of corrections:")
print("   - User: 'No, use files instead of Redis'")
print("   - User: 'Actually, prefer pytest over unittest'")
print("   - User: 'Use TypeScript, not JavaScript'")
print("")
print("4. For each correction found, extract:")
print("   - What was rejected")
print("   - What was preferred")
print("   - Is it project-specific or general?")
print("")
print("5. Create a JSON structure like this:")
print("")
print("```json")
print("{")
print('  "preferences": [')
print("    {")
print('      "type": "prefer",')
print('      "subject": "pytest over unittest",')
print('      "context": "Python testing",')
print('      "scope": "language",  // or "project" or "global"')
print('      "raw_text": "Actually, prefer pytest over unittest",')
print('      "confidence": 0.9')
print("    }")
print("  ]")
print("}")
print("```")
print("")
print("6. Once you've created the JSON, I'll save it to the memory file.")
```

```bash
echo ""
echo "---"
echo ""
echo "**After you provide the JSON structure above**, run:"
echo ""
echo "  /amplicode-save-preferences"
echo ""
echo "to save the extracted preferences to .data/memory.json"
```
