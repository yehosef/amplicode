# Using Claude Code for Learning (No API Costs!)

**User insight:** "I'm already paying $200/month for Claude - why pay for API access?"

**Solution:** Use Claude Code itself as the learning engine.

---

## Architecture Options

### Option 1: Auto-Learning on SessionStart (RECOMMENDED)

**How it works:**
1. SessionStart hook detects queued events
2. Hook writes special file: `.claude/pending_learning.md`
3. This file is AUTOMATICALLY loaded by Claude Code as context
4. Claude sees: "Hey, analyze these corrections and update memory.json"
5. Claude does it automatically at session start
6. No user action needed!

**Pros:**
- ✅ Fully automatic
- ✅ Uses Claude Pro subscription (already paid)
- ✅ No API costs
- ✅ Happens every session
- ✅ Transparent (user sees the analysis)

**Cons:**
- ⚠️ Happens at start of EVERY session (might be slow)
- ⚠️ Claude might not always do it (could forget)

**Implementation:**

```bash
# In sessionstart_hook.sh

QUEUE_FILE="$HOME/.claude/learning_queue.jsonl"
LEARNING_PROMPT="$PROJECT_ROOT/.claude/pending_learning.md"

# Check if there are queued events
if [ -f "$QUEUE_FILE" ] && [ -s "$QUEUE_FILE" ]; then
    QUEUE_SIZE=$(wc -l < "$QUEUE_FILE")

    if [ "$QUEUE_SIZE" -gt 0 ]; then
        # Create a file that Claude will see in context
        cat > "$LEARNING_PROMPT" << EOF
# 🧠 Amplicode Learning Task

**You have $QUEUE_SIZE queued learning events to process.**

## Instructions

1. **Read** the queue file: \`~/.claude/learning_queue.jsonl\`
2. **Analyze** the events for corrections (when user rejected your suggestion)
3. **Extract** preferences from corrections
4. **Update** \`.data/memory.json\` with new preferences
5. **Clear** the queue file after processing

## What to look for

A correction is when:
- User says "No, use X instead"
- User says "Actually, prefer Y"
- User rejects your approach and specifies alternative

## Memory format

\`\`\`json
{
  "preferences": [
    {
      "type": "prefer",
      "subject": "local files over Redis",
      "scope": "project",
      "confidence": 0.9,
      "learned_at": "ISO timestamp"
    }
  ]
}
\`\`\`

**Please process these events now and update the memory file.**

After processing, delete this file: \`.claude/pending_learning.md\`
EOF

        echo "🧠 Learning prompt created - Claude will process on startup"
    fi
fi
```

---

### Option 2: Slash Command (Manual Trigger)

**How it works:**
User runs `/amplicode-process` when they want

**Pros:**
- ✅ User controls when it happens
- ✅ Uses Claude Pro subscription
- ✅ No API costs
- ✅ User sees the analysis in real-time

**Cons:**
- ⚠️ Requires user action
- ⚠️ User might forget

---

### Option 3: Background Claude CLI (If Available)

**How it works:**
Worker calls `claude` CLI with prompt, gets response

**Pros:**
- ✅ Fully automatic
- ✅ No user action needed
- ✅ Uses Claude Pro subscription

**Cons:**
- ❌ Need to verify `claude` CLI supports non-interactive mode
- ❌ Might not have access to conversation history
- ❌ More complex to implement

**Investigation needed:**
```bash
# Check if claude CLI exists
which claude

# Check if it supports piping
echo "Analyze this: ..." | claude

# Check for headless mode
claude --help | grep -i batch
claude --help | grep -i non-interactive
```

---

## Recommendation: Hybrid Approach

1. **Default:** Auto-learning on SessionStart (Option 1)
   - Most sessions, Claude processes queue automatically
   - Lightweight - just creates a context file

2. **Fallback:** Manual slash command (Option 2)
   - If auto-learning doesn't happen, user can trigger manually
   - `/amplicode-process`

3. **Future:** Claude CLI if available (Option 3)
   - Investigate if `claude` CLI can run headlessly
   - Could enable true background processing

---

## Implementation Plan

### Phase 1: Auto-Learning (This Week)
- [x] Modify sessionstart_hook.sh to detect queue
- [x] Create .claude/pending_learning.md with instructions
- [x] Test that Claude sees and processes it
- [x] Verify memory.json updates correctly

### Phase 2: Manual Command (Backup)
- [x] Create /amplicode-process command
- [x] Shows queued events
- [x] Prompts Claude to analyze
- [x] Claude updates memory.json

### Phase 3: CLI Investigation (Future)
- [ ] Research `claude` CLI capabilities
- [ ] Test non-interactive mode
- [ ] Implement if viable

---

## Benefits vs API Approach

| Aspect | API Approach | Claude Code Approach |
|--------|-------------|---------------------|
| **Cost** | Extra API fees | $0 (already paying $200/month) |
| **Context** | Limited to prompt | Full conversation history |
| **Transparency** | Hidden background | User sees analysis |
| **Control** | Automatic | User can review/modify |
| **Integration** | Separate system | Native to Claude Code |
| **Rate Limits** | API limits | No limits (local) |

---

## User Experience

### Automatic (Option 1)

**Session 1:**
```
User: "Add auth"
Claude: "I'll use JWT with Redis..."
User: "No, use local files"
→ Queued

Session ends
```

**Session 2:**
```
SessionStart hook: "Found 1 queued event"
Claude sees: "🧠 Learning task - analyze queue and update memory"
Claude: *reads queue, finds correction, updates memory.json*
Claude: "I've learned that this project prefers local files over Redis"

User: "Add user profiles"
Claude: "I'll set up local file-based sessions..." ← Already learned!
```

### Manual (Option 2)

```
User: /amplicode-process

Claude: "Found 3 queued events. Let me analyze..."
Claude: *shows analysis*
Claude: "I found 2 corrections:"
  1. Prefer local files over Redis (project-specific)
  2. Prefer pytest over unittest (language-specific)

Claude: *updates memory.json*
Claude: "✅ Preferences saved. I'll remember these next session."
```

---

## Next Steps

1. **Test Option 1** - Does Claude automatically process `.claude/pending_learning.md`?
2. **Implement Option 2** - Manual slash command as backup
3. **Investigate Option 3** - Check if `claude` CLI has batch mode
4. **Choose best approach** based on testing

---

## Key Insight

**We don't need the Anthropic API at all.**

Claude Code is ALREADY an LLM with full context. We just need to:
1. Tell Claude what to analyze (queue file)
2. Tell Claude where to write results (memory.json)
3. Give Claude the instructions (pending_learning.md)

This is actually MORE powerful than API calls because Claude has:
- Full conversation history
- Access to all project files
- Understanding of project context
- Ability to use tools (Read, Write, Edit)

**The LLM is already running. We just need to ask it to do the work.**
