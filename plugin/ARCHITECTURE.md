# Amplicode Architecture: Claude Code Self-Learning

**Key Insight:** Use Claude Code itself for learning extraction (no API costs!)

---

## Overview

Amplicode uses **Claude Code as its own learning engine**. Instead of calling external APIs, Claude analyzes its own conversation history and extracts preferences.

```
User correction → Queue → SessionStart → Claude sees learning task → Claude updates memory
                                               ↓
                                    Uses existing $200/month subscription
                                    (No extra API costs!)
```

---

## How It Works

### 1. Hooks Capture Events

**stop_hook.sh** (fires after every Claude response):
```bash
# Queues event to ~/.claude/learning_queue.jsonl
{"project":"/path/to/project","event_type":"stop","timestamp":1729530000}
```

**sessionend_hook.sh** (fires when session ends):
```bash
# Queues session end event
{"project":"/path/to/project","event_type":"session_end","timestamp":1729530100}
```

### 2. SessionStart Detects Pending Learning

**sessionstart_hook.sh** (fires when new session starts):
```bash
# Checks if queue has events
if [ queue has events ]; then
    # Creates .claude/pending_learning.md with instructions
    # This file is AUTOMATICALLY loaded by Claude Code as context!
fi
```

### 3. Claude Processes Automatically

When Claude Code starts, it sees `.claude/pending_learning.md` in the project context:

```markdown
# 🧠 Amplicode Auto-Learning Task

You have 5 queued learning events to process.

## Your Task
1. Read ~/.claude/learning_queue.jsonl
2. Analyze conversation history for corrections
3. Extract preferences
4. Update .data/memory.json
5. Clear queue and delete this file

## What is a correction?
User: "Add auth"
Claude: "I'll use JWT with Redis..."
User: "No, use local files instead"
      ↑ CORRECTION!
```

Claude sees this and:
1. Reads the queue file
2. Looks back at conversation history
3. Finds corrections (when user rejected suggestions)
4. Extracts preferences
5. Updates `.data/memory.json`
6. Clears queue

### 4. Next Session Loads Preferences

**sessionstart_hook.sh** displays learned preferences:
```bash
✅ Loaded 3 learned preference(s) for this project
```

Claude reads `.data/memory.json` and knows:
- "This project prefers local files over Redis"
- "User prefers pytest for Python testing"
- etc.

---

## Benefits vs API Approach

| Aspect | API Approach | Claude Code Approach |
|--------|-------------|---------------------|
| **Cost** | Extra $$ for API | $0 (already paying $200/month) |
| **Context** | Limited prompt | **Full conversation history** |
| **Transparency** | Hidden | **User sees analysis** |
| **Control** | Automatic | **User can review/modify** |
| **Integration** | External | **Native to Claude Code** |
| **Rate Limits** | API limits | **No limits** |
| **Accuracy** | Depends on prompt | **Has full context** |

---

## Memory Structure

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
    },
    {
      "type": "prefer",
      "subject": "pytest over unittest",
      "context": "User corrected: 'Actually, prefer pytest'",
      "scope": "language",
      "confidence": 0.90,
      "learned_at": "2025-10-22T02:35:00"
    }
  ],
  "version": "1.0",
  "updated_at": "2025-10-22T02:35:00"
}
```

**Scopes:**
- `"project"` - This codebase only
- `"language"` - All projects in this language
- `"global"` - All projects everywhere

---

## File Locations

### Global (Shared)
```
~/.claude/
├── learning_queue.jsonl          # Events from all projects
└── learning_queue_archive.jsonl  # Processed events
```

### Per-Project
```
<project>/
├── .data/
│   ├── memory.json                # Learned preferences
│   └── memory.json.backup         # Backup
└── .claude/
    └── pending_learning.md        # Auto-learning prompt (created by SessionStart)
```

---

## Worker (Simplified)

The worker is now **much simpler** - it doesn't do LLM extraction anymore!

**Old role:** Queue events → Call API → Extract preferences
**New role:** Monitor queue → Archive old events → Provide stats

```python
# learning_worker.py (simplified)

while True:
    # Monitor queue size
    queue_size = count_events(QUEUE_FILE)

    # Archive old events (>7 days)
    archive_old_events()

    # Write stats
    write_heartbeat(queue_size)

    # Sleep
    time.sleep(10)
```

**Optional:** You can disable the worker entirely if you don't need stats/archiving.

---

## User Experience

### Session 1: User Makes Correction

```
User: "Add authentication"
Claude: "I'll use JWT with Redis for session storage..."
User: "No, use local file-based sessions instead"

→ stop_hook.sh queues this event

Session ends
→ sessionend_hook.sh queues session end event
```

### Session 2: Auto-Learning Happens

```
SessionStart:
→ Detects 2 queued events
→ Creates .claude/pending_learning.md

Claude sees:
"🧠 You have 2 queued events. Analyze for corrections..."

Claude thinks:
"Let me check the queue... I see a stop event and session end."
"Looking back at the conversation... ah, user said 'No, use local files'"
"That's a correction - they rejected Redis and prefer local files."
"This seems project-specific (they mentioned 'this app')."
"Let me update .data/memory.json..."

Claude does:
1. Reads queue
2. Analyzes conversation
3. Finds correction about Redis → local files
4. Updates memory.json with preference
5. Clears queue
6. Deletes pending_learning.md

User sees:
"✅ Loaded 1 learned preference(s) for this project"
```

### Session 3: Preference Applied

```
User: "Add user profiles"
Claude: "I'll set up local file-based session storage..."
       ↑ Already knows the preference!

No correction needed!
```

---

## Manual Processing (Backup)

If auto-learning doesn't happen, user can trigger manually:

```
/amplicode-process
```

Claude will:
1. Read queue
2. Analyze and extract preferences
3. Update memory.json
4. Show what was learned

---

## Advantages of This Approach

### 1. **No API Costs**
Already paying $200/month for Claude Pro - why pay more?

### 2. **Full Context**
Claude has the ENTIRE conversation history, not just isolated events.

### 3. **Transparency**
User can see:
- What events were queued
- What Claude learned
- The exact preferences in memory.json

### 4. **User Control**
- Can review preferences before they're applied
- Can edit/delete incorrect preferences
- Can manually trigger processing

### 5. **More Accurate**
Claude understands context, tone, and nuance better than keyword matching.

### 6. **Native Integration**
Uses Claude Code's existing tools (Read, Write, Edit) and context loading.

---

## Technical Details

### How Does Claude See the Prompt?

`.claude/pending_learning.md` is in the project directory. Claude Code automatically loads files in `.claude/` as context (if they're markdown or in certain locations).

When SessionStart creates this file, Claude sees it immediately on startup.

### What If Claude Doesn't Process It?

- User can manually run `/amplicode-process`
- User can check `/amplicode-status` to see queue size
- File stays in `.claude/` until processed
- Next session start will show it again

### Can I Disable Auto-Learning?

Yes, remove `.claude/pending_learning.md` or modify sessionstart hook to not create it.

---

## Future Enhancements

### Global Preferences
```
~/.claude/global_memory.json
```
Preferences that apply to ALL projects.

### Language-Specific
```
~/.claude/context_memory.json
```
Preferences per language/framework.

### Auto-Promotion
If same preference appears in 3+ projects → promote to global.

### Confidence Scoring
Track how often preferences are applied vs rejected.

---

## Why This Is Better

**Original plan:** Build complex LLM extraction with API calls

**New plan:** Ask Claude to analyze its own conversation

**Result:**
- Simpler implementation
- No API costs
- Better accuracy (full context)
- More transparent
- User maintains control

**Claude Code is already an LLM with full context. We just need to ask it to do the work.**

---

## Summary

1. **Hooks queue events** (simple, fast)
2. **SessionStart creates learning prompt** (automatic)
3. **Claude analyzes and updates memory** (uses existing subscription)
4. **Next session loads preferences** (seamless)

**Total cost:** $0 extra (already paying for Claude Pro)

**This is the way.**
