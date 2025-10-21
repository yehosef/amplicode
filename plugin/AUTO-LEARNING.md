# Automatic Learning - How It Works

**Key Feature:** Amplicode automatically triggers Claude Code to process learning - NO USER ACTION NEEDED!

---

## The Complete Flow

### 1. You Make Corrections (During Work)

```
You: "Add authentication"
Me: "I'll use JWT with Redis for sessions..."
You: "No, use local file-based sessions instead"

→ stop_hook.sh queues this event to ~/.claude/learning_queue.jsonl
```

Every time you correct my suggestion, it gets queued.

### 2. Monitor Detects Threshold (Background)

The **learning_monitor.py** runs in the background (started by SessionStart hook):

```python
while True:
    queue_size = count_events()  # Check queue

    if queue_size >= 10:  # Threshold reached!
        trigger_claude_processing()  # Automatically trigger!

    sleep(30)  # Check every 30 seconds
```

### 3. Monitor Triggers Claude Code (Automatic!)

When queue reaches 10 events, monitor calls **trigger_claude_learning.sh**:

```bash
# On macOS, uses AppleScript to send command to Claude Code
osascript <<EOF
tell application "Claude"
    activate
    keystroke "/amplicode-process"
    key code 36  # Enter
end tell
EOF
```

This:
- Brings Claude Code to front
- Types the `/amplicode-process` command
- Hits Enter
- **You see it happen in real-time!**

### 4. Claude Code Processes Automatically

I (Claude) see the command and:
1. Read `~/.claude/learning_queue.jsonl`
2. Analyze conversation history for corrections
3. Extract preferences from corrections
4. Update `.data/memory.json`
5. Clear the queue

**You see this happening** - I'll show you what I learned!

### 5. Next Session: Preferences Loaded

```
SessionStart: "✅ Loaded 3 learned preference(s) for this project"

You: "Add user profiles"
Me: "I'll set up local file-based session storage..."
    ↑ Already knows your preference!
```

---

## Key Components

### learning_monitor.py (Background Process)

```
~/.claude/learning_monitor.py
```

**What it does:**
- Runs in background (started by SessionStart hook)
- Checks queue size every 30 seconds
- When queue >= 10 events → triggers Claude Code
- Doesn't trigger too frequently (5 min cooldown)
- Archives old events (>7 days)
- Writes heartbeat for monitoring

**Monitor heartbeat:**
```json
{
  "queue_size": 8,
  "last_trigger": "2025-10-22T14:30:00",
  "trigger_threshold": 10
}
```

### trigger_claude_learning.sh (Automation Script)

```
~/.claude/trigger_claude_learning.sh
```

**What it does:**
- Called by monitor when threshold reached
- Uses AppleScript to control Claude Code (macOS)
- Sends `/amplicode-process` command
- Falls back to creating pending_learning.md if AppleScript fails

**AppleScript automation:**
```applescript
tell application "Claude"
    activate
    keystroke "/amplicode-process"
    key code 36  -- Enter
end tell
```

### /amplicode-process (Slash Command)

**What it does:**
- Reads queue events
- Shows them to you
- Analyzes conversation for corrections
- Updates memory.json
- Clears queue

**You see the entire process!**

---

## Configuration

### Trigger Threshold

Default: 10 events

Change in `learning_monitor.py`:
```python
TRIGGER_THRESHOLD = 10  # Change this
```

### Check Interval

Default: 30 seconds

Change in `learning_monitor.py`:
```python
CHECK_INTERVAL = 30  # Change this
```

### Archive Age

Default: 7 days

Change in `learning_monitor.py`:
```python
ARCHIVE_AGE_DAYS = 7  # Change this
```

---

## Platform Support

### macOS (Full Support)

✅ AppleScript automation works
✅ Monitor can trigger Claude Code automatically
✅ You see it happen in real-time

### Linux/Windows (Partial Support)

⚠️ No AppleScript support
✅ Monitor still creates pending_learning.md
✅ Claude Code sees it on next session start
⚠️ Not fully automatic - requires session restart

---

## Monitoring

### Check Monitor Status

```
/amplicode-status
```

Shows:
- Monitor PID and health
- Queue size
- Last trigger time
- Next trigger threshold

### View Monitor Logs

```bash
tail -f ~/.claude/monitor.log
```

See:
- Queue size checks
- When triggers happened
- Any errors

### Manual Trigger

If you want to process immediately (don't wait for threshold):

```
/amplicode-process
```

---

## How It Feels

### As a User

1. **Work normally** - Make corrections as needed
2. **Every ~10 corrections** - Claude Code pops up and processes
3. **You see it happen** - Transparent, not hidden
4. **Review results** - See what Claude learned
5. **Next session** - Preferences automatically applied

### What You See

```
[Working in terminal...]

[Claude Code window comes to front]
Claude: "Processing 12 queued learning events..."
Claude: "Found 3 corrections:"
  1. Prefer local files over Redis (project-specific)
  2. Prefer pytest over unittest (Python)
  3. Prefer descriptive variable names (global)
Claude: "Updated .data/memory.json"
Claude: "Cleared queue"

[You can review and continue working]
```

---

## Benefits

### ✅ Fully Automatic
- No user action needed
- Happens in background
- Triggers at right time

### ✅ Transparent
- You see when it happens
- You see what was learned
- You can review immediately

### ✅ Controllable
- Change threshold
- Change frequency
- Manual trigger available
- Edit/delete preferences

### ✅ No API Costs
- Uses your Claude Pro subscription ($200/month)
- No extra fees
- No rate limits

### ✅ Platform Native
- Uses AppleScript on macOS
- Respects system automation
- Proper app activation

---

## Comparison

### Before (Manual)
```
User makes corrections →
Queue fills up →
User manually runs /amplicode-process →
Claude processes
```

### After (Automatic)
```
User makes corrections →
Queue fills up →
Monitor detects threshold →
Monitor triggers Claude Code automatically →
Claude processes →
User sees it happen
```

---

## Troubleshooting

### Monitor Not Running

```bash
# Check if running
pgrep -f learning_monitor.py

# If not, it will start on next SessionStart
# Or manually start:
python3 ~/.claude/learning_monitor.py &
```

### AppleScript Permission Denied

```bash
# macOS may need permission to control Claude Code
# Go to: System Settings > Privacy & Security > Automation
# Allow Terminal/Claude Code to control Claude Code
```

### Threshold Never Reached

If you don't make 10 corrections often:

```python
# Lower threshold in learning_monitor.py
TRIGGER_THRESHOLD = 5  # or 3
```

### Want to Disable Automatic Triggering

```bash
# Stop the monitor
pkill -f learning_monitor.py

# Won't restart until next SessionStart
# Can still manually run /amplicode-process
```

---

## Summary

**You asked:** "I don't want the user to have to trigger the process - I want the code to do it"

**Solution:**
1. Monitor runs in background
2. Detects when queue reaches threshold
3. Automatically triggers Claude Code via AppleScript
4. Claude processes and shows you what was learned
5. No user action needed!

**This is fully automatic learning that's still transparent and controllable.**

🎉 **You make corrections. The system learns. You see it happen. No manual steps required.**
