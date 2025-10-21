# Hook Architecture Recommendation: Background Learning System

**Date:** 2025-10-22 (Updated with Plugin Distribution)
**Status:** Recommended Architecture - Approved for Plugin Implementation
**Decision:** Build background processing system for learning from corrections
**Distribution:** Claude Code Plugin (see FINAL-ARCHITECTURE.md for implementation details)

---

> **Update 2025-10-22:** This architecture has been approved and adapted for Claude Code plugin distribution. The core architecture remains unchanged - the plugin auto-installs hooks and manages the global worker lifecycle. See [FINAL-ARCHITECTURE.md](FINAL-ARCHITECTURE.md) for plugin-specific implementation details.

---

## Executive Summary

After deep analysis of Claude Code hooks and consideration of background processing capabilities, we recommend a **three-tier background learning architecture** that captures user corrections in real-time without impacting Claude Code responsiveness.

**Key Insight:** The ability to run background processes fundamentally changes hook strategy. Instead of limiting expensive operations to SessionEnd only, we can capture high-value learning signals (corrections) as they happen using a queue-and-worker pattern.

**Core Value:** Capture the "correction pattern" - when users reject Claude's approach and specify what they prefer instead. This is **preference learning**, far more valuable than generic session summaries.

---

## The Problem: Context Loss and Repeated Corrections

### What Happens Today (Without Learning)

```
Session 1:
User: "Add authentication"
Claude: "I'll use JWT with Redis session storage..."
User: "No, don't use Redis. Use local file-based sessions."
Claude: "Got it, using local files..."

Session 2 (next day):
User: "Add user profiles"
Claude: "I'll set up Redis for session management..."
User: "NO! We're using local files, not Redis!" 😤
Claude: "Sorry, using local files..."

Session 3:
User: "Add password reset"
Claude: "Let me configure Redis..."
User: "FOR THE LAST TIME, NO REDIS!" 🤬
```

**The user is teaching Claude the same lesson repeatedly.**

### What Should Happen (With Learning)

```
Session 1:
User: "Add authentication"
Claude: "I'll use JWT with Redis..."
User: "No, use local files instead."
→ SYSTEM LEARNS: User prefers file-based over Redis for this project

Session 2:
[SessionStart loads memory]
Claude receives context: "Previous learning: User prefers local file sessions over Redis (reasoning: simplicity)"

User: "Add user profiles"
Claude: "I'll use local file-based sessions (based on your preference)..."
User: "Perfect!" ✅
```

**Context compounds. User doesn't repeat themselves.**

---

## The Correction Pattern: Highest-Value Signal

### What is a Correction?

A correction happens when:
1. Claude proposes an approach
2. User explicitly rejects it
3. User specifies preferred alternative

**Example Patterns:**
- "No, don't do X, do Y instead"
- "Not that approach, use this one"
- "Don't use Redis, use local files"
- "Skip the framework, write it from scratch"
- "No tests needed for this"

### Why Corrections are Gold

**It's preference learning, not event logging:**
- **Explicit**: User clearly states what they don't want
- **Actionable**: User provides alternative
- **Contextual**: Tied to specific decision
- **Repeatable**: Pattern likely applies to future decisions
- **High signal**: User bothered to correct (cares about this)

**Frequency:** 5-10 corrections per session (frequent enough to matter)

**Value:** Each correction teaches Claude about user's preferences, conventions, and project constraints.

---

## Hook Frequency Analysis

Understanding when hooks fire is critical to architecture:

| Hook | Frequency | Example Count | Can Be Slow? |
|------|-----------|---------------|--------------|
| **Stop** | After every Claude response | 50-100/session | ❌ No (blocks frequently) |
| **PostToolUse** | After every tool call | 100-200/session | ❌ No (very frequent) |
| **UserPromptSubmit** | Each user message | 20-50/session | ❌ No (blocks user) |
| **SessionEnd** | Once per session | 1/session | ✅ Yes (ending anyway) |
| **SessionStart** | Once per session | 1/session | ✅ Yes (startup) |
| **PreCompact** | Rarely | 0-2/session | ⚠️ Maybe (unexpected) |

**Critical Realization:** Stop hook fires after **every single response**.

Amplifier puts heavy LLM extraction in Stop hook → requires opt-in because it's too expensive.

**Our innovation:** Stop hook just appends to queue (fast), worker does expensive work in background.

---

## Architecture Decision: Background Processing

### The Paradigm Shift

**Without background processing:**
```
Hook fires → Do work → Block until done → Return control
```
**Problem:** Frequent hooks can't do expensive work (LLM calls)

**With background processing:**
```
Hook fires → Append to queue → Return immediately
Worker (separate process) → Poll queue → Do expensive work → Update memory
```
**Advantage:** Hooks stay fast, expensive work happens async

### Technology Choice: All Python

**Considered Options:**
1. **All Python** - Simple, matches Amplifier ✅ CHOSEN
2. Hybrid (Node.js worker, Python hooks) - Fastest, but two languages
3. All Node.js - Diverges from Amplifier, need to port utilities

**Decision Rationale:**
- Single language reduces complexity
- Python is "fast enough" for this workload
- Matches Amplifier's implementation (learning from their code easier)
- Worker startup time doesn't matter (long-running process)
- ~500ms startup for hooks is acceptable (once per session)

---

## Recommended Architecture

### Three-Tier System

```
┌──────────────────────────────────────────────────────────┐
│                    TIER 1: HOOKS (Fast)                   │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  hook_stop.py              (30 lines)                    │
│  • Detect correction keywords in transcript             │
│  • Append to queue: {type: "correction", data: {...}}   │
│  • Exit immediately (<100ms)                             │
│                                                           │
│  hook_sessionend.py        (20 lines)                    │
│  • Queue full session for analysis                       │
│  • Backup transcript                                     │
│  • Exit immediately (<100ms)                             │
│                                                           │
│  hook_sessionstart.py      (40 lines)                    │
│  • Load learned preferences from memory.json            │
│  • Inject as additional context for Claude              │
│  • Start worker if not running                          │
│  • Can be slow (once per session)                       │
│                                                           │
└──────────────────┬───────────────────────────────────────┘
                   │ Write JSONL
                   ▼
┌──────────────────────────────────────────────────────────┐
│                 TIER 2: QUEUE (Simple)                    │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  .data/learning_queue.jsonl                              │
│  • One JSON object per line                              │
│  • Append-only (no locking on write)                     │
│  • Format: {type, timestamp, session_id, data}          │
│  • Rotates when >10MB                                    │
│                                                           │
└──────────────────┬───────────────────────────────────────┘
                   │ Poll every 1 second
                   ▼
┌──────────────────────────────────────────────────────────┐
│              TIER 3: WORKER (Parallel)                    │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  amplicode/learning/worker.py     (150 lines)           │
│  • Long-running background process                       │
│  • Polls queue every 1 second                           │
│  • Dispatches events to extractors                      │
│  • Manages worker lifecycle                             │
│                                                           │
│  amplicode/learning/extractor.py  (120 lines)           │
│  • LLM-based learning extraction                        │
│  • extract_correction(transcript_snippet)               │
│  • extract_session(full_transcript)                     │
│  • Uses defensive utilities (parse_llm_json, retry)     │
│                                                           │
│  amplicode/learning/memory.py     (100 lines)           │
│  • Read/write .data/memory.json with locking           │
│  • Schema: preferences, learnings, decisions, patterns  │
│                                                           │
│  amplicode/learning/queue.py      (80 lines)            │
│  • Queue operations: append, poll, archive              │
│  • Track processing offset                              │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

### Data Flow: Correction Capture

```
1. USER CORRECTS CLAUDE
   User: "Add auth to API"
   Claude: "I'll use JWT with Redis session storage..."
   User: "No, use local file-based sessions instead"

2. STOP HOOK FIRES (< 100ms)
   hook_stop.py:
   • Reads last 3 messages from transcript
   • Detects "No" keyword after Claude response
   • Appends to queue.jsonl:
     {
       "type": "correction",
       "timestamp": "2025-10-21T14:30:00Z",
       "session_id": "abc123",
       "data": {
         "transcript_path": "/path/to/transcript.jsonl",
         "trigger_offset": 42  // line number
       }
     }
   • Exits (Claude Code continues)

3. WORKER PROCESSES (Parallel, non-blocking)
   worker.py polls queue every 1 second:
   • Finds correction event
   • Calls extractor.extract_correction():
     - Reads transcript around line 42
     - Sends to LLM with prompt:
       "Analyze this correction. Extract:
        1. What Claude proposed
        2. What user rejected
        3. What user prefers
        4. Why (inferred)"
   • Parses LLM response (defensively)
   • Writes to memory.json:
     {
       "preferences": [{
         "context": "authentication implementation",
         "rejected": "JWT with Redis session storage",
         "preferred": "local file-based sessions",
         "reasoning": "simplicity over distributed systems",
         "timestamp": "2025-10-21T14:30:15Z",
         "confidence": 0.85
       }]
     }

4. NEXT SESSION STARTS
   hook_sessionstart.py:
   • Reads memory.json
   • Finds preferences related to prompt
   • Injects as context:
     "Previous learnings:
      - For authentication, prefer local file sessions over Redis
      - Reasoning: simplicity over distributed systems"
   • Claude now aware of preference from the start!
```

---

## Hook Strategy

### ✅ USE THESE HOOKS

#### 1. **Stop** - Detect Corrections
**When:** After every Claude response (50-100x per session)
**What:** Pattern matching for correction keywords, queue if detected
**Why:** Captures highest-value learning signal (user preferences)
**Speed:** < 100ms (just file append)

**Pattern Detection:**
```python
correction_keywords = [
    "no", "don't", "not that", "instead",
    "actually", "rather", "prefer", "skip"
]

def potential_correction_detected(transcript):
    last_messages = get_last_n_messages(transcript, n=3)
    if len(last_messages) < 3:
        return False

    user_msg = last_messages[-1]  # Most recent
    if any(keyword in user_msg.lower() for keyword in correction_keywords):
        return True
    return False
```

#### 2. **SessionEnd** - Queue Full Analysis
**When:** Once per session
**What:** Queue entire session for pattern extraction
**Why:** Catch high-level patterns missed by per-response analysis
**Speed:** < 100ms (just queue append)

**Extracts:**
- Recurring patterns ("always does X")
- Final decisions made
- Problems solved in session
- Anti-patterns discovered

#### 3. **SessionStart** - Load Context
**When:** Once per session
**What:** Load learned preferences, inject as context, start worker
**Why:** Closes the learning loop (apply what was learned)
**Speed:** Can be slow (1-2 seconds OK, happens once)

**Loads:**
```python
def load_preferences():
    memory = read_memory_json()
    return {
        "preferences": memory.get("preferences", []),
        "patterns": memory.get("patterns", []),
        "anti_patterns": memory.get("anti_patterns", [])
    }

def format_for_claude(preferences):
    context = ["Previous learnings about this project:"]
    for pref in preferences:
        context.append(
            f"- {pref['context']}: Prefer {pref['preferred']} "
            f"over {pref['rejected']} ({pref['reasoning']})"
        )
    return "\n".join(context)
```

### ⚠️ MAYBE ADD LATER

#### 4. **PreCompact** - Emergency State Save
**When:** Rarely (when context about to compact)
**What:** Save current state snapshot
**Why:** Safety net if compaction happens mid-task
**Speed:** < 10 seconds (rare event)

**Saves:**
```json
{
  "current_task": "from TodoWrite",
  "files_in_progress": ["list of modified files"],
  "unresolved_questions": ["extracted questions"],
  "next_action": "inferred next step"
}
```

**NOT full transcripts** - just enough to resume.

#### 5. **PostToolUse** - Tool-Level Learning
**When:** After every tool call (100-200x per session)
**What:** Quick pattern detection (no LLM)
**Why:** Learn tool usage patterns
**Speed:** Must be < 100ms

**Example:**
```python
def on_post_tool_use(tool_name, file_path):
    if tool_name == "Edit" and file_path.startswith("auth/"):
        # Critical file edited, flag for extraction
        flag_for_session_end(f"auth system modified: {file_path}")
```

**Phase 2 only** - skip for MVP.

### ❌ DON'T USE THESE

#### **UserPromptSubmit** - Wrong Timing
**Why skip:** Fires before Claude responds, can't detect corrections yet.

#### **SubagentStop** - Not Needed Yet
**Why skip:** Only relevant when we have multiple specialized agents (Phase 4+).

#### **Notification** - Not Relevant
**Why skip:** Not related to learning system.

---

## Memory Schema

### Storage: `.data/memory.json`

**Format:** Single JSON file with categories

```json
{
  "version": "1.0",
  "last_updated": "2025-10-21T14:30:00Z",

  "preferences": [
    {
      "id": "uuid-v4",
      "timestamp": "2025-10-21T14:30:00Z",
      "context": "authentication implementation",
      "rejected": "JWT with Redis session storage",
      "preferred": "local file-based sessions",
      "reasoning": "simplicity over distributed systems",
      "confidence": 0.85,
      "occurrences": 1,
      "last_reinforced": "2025-10-21T14:30:00Z"
    }
  ],

  "decisions": [
    {
      "id": "uuid-v4",
      "timestamp": "2025-10-21T13:15:00Z",
      "decision": "Using JSONL for queue instead of database",
      "reasoning": "Ruthless simplicity - no external dependencies",
      "context": "Learning system architecture",
      "alternatives_considered": ["Redis", "SQLite", "In-memory queue"]
    }
  ],

  "patterns": [
    {
      "id": "uuid-v4",
      "timestamp": "2025-10-21T12:00:00Z",
      "pattern": "Always run tests after editing auth/ directory",
      "context": "Security-critical code",
      "occurrences": 3,
      "confidence": 0.9
    }
  ],

  "anti_patterns": [
    {
      "id": "uuid-v4",
      "timestamp": "2025-10-21T11:30:00Z",
      "anti_pattern": "Don't use non-recursive glob patterns (*.md)",
      "reason": "Misses nested files",
      "correct_approach": "Use recursive globs (**/*.md)",
      "source": "Tool generation failures"
    }
  ],

  "learnings": [
    {
      "id": "uuid-v4",
      "timestamp": "2025-10-21T10:00:00Z",
      "category": "solution",
      "content": "Cloud sync I/O errors solved with retry logic and exponential backoff",
      "context": "File operations on OneDrive folders",
      "tags": ["io", "cloud-sync", "error-handling"]
    }
  ]
}
```

### Why This Schema?

**Categories match Amplifier's proven patterns:**
- `preferences` - **New** - User's explicit preferences (corrections)
- `decisions` - Architectural choices made
- `patterns` - Recurring successful approaches
- `anti_patterns` - Things that don't work
- `learnings` - Generic insights and solutions

**Preferences are first-class** because corrections are the highest-value signal.

---

## Extraction Strategies

### Phase 1: Pattern-Based (Simple, Fast)

For SessionEnd hook, use simple regex:

```python
def extract_learnings_pattern_based(transcript):
    learnings = []

    for msg in transcript:
        text = msg["content"].lower()

        # Decision pattern
        if any(k in text for k in ["decided to", "chose to", "going with"]):
            learnings.append({
                "category": "decision",
                "content": extract_sentence_around_keyword(msg),
                "confidence": 0.7
            })

        # Pattern pattern
        if any(k in text for k in ["always", "whenever", "every time"]):
            learnings.append({
                "category": "pattern",
                "content": extract_sentence_around_keyword(msg),
                "confidence": 0.6
            })

        # Solution pattern
        if any(k in text for k in ["solved by", "fixed by", "resolved"]):
            learnings.append({
                "category": "solution",
                "content": extract_sentence_around_keyword(msg),
                "confidence": 0.8
            })

    return learnings
```

**Advantages:**
- Fast (no LLM calls)
- Deterministic
- Zero API cost
- Easy to debug
- Amplifier proves this works (DISCOVERIES.md)

### Phase 2: LLM-Based (Accurate, Expensive)

For correction extraction, use LLM:

```python
async def extract_correction_llm(transcript_snippet):
    prompt = f"""
    Analyze this conversation where a user corrected Claude's approach.

    Extract:
    1. What Claude proposed
    2. What the user rejected
    3. What the user prefers instead
    4. Why the user prefers it (inferred from context)

    Return JSON:
    {{
      "rejected": "...",
      "preferred": "...",
      "reasoning": "...",
      "confidence": 0.0-1.0
    }}

    Conversation:
    {transcript_snippet}
    """

    response = await retry_with_feedback(
        call_llm,
        prompt=isolate_prompt(prompt),  # Prevent injection
        max_retries=3
    )

    return parse_llm_json(response)  # Defensive parsing
```

**Advantages:**
- High accuracy
- Understands context
- Infers reasoning

**Disadvantages:**
- Slower (~5-10 seconds per correction)
- API cost (~$0.01 per correction)
- Can fail (needs retry logic)

**Mitigation:** Run in background worker, doesn't block interaction.

---

## Implementation Phases

### Week 1: Infrastructure

**Days 1-2: Queue & Memory**
```
[ ] amplicode/learning/queue.py
    - append(event)
    - poll() → list of events
    - archive(when >10MB)

[ ] amplicode/learning/memory.py
    - read_memory() → dict
    - write_memory(dict)
    - append_preference(pref)
    - File locking with fcntl

[ ] Tests:
    - Concurrent writes (3 processes)
    - Queue rotation
    - Memory schema validation
```

**Days 3-4: Worker Core**
```
[ ] amplicode/learning/worker.py
    - Main loop: poll → process → sleep(1)
    - Event dispatch: correction vs session_end
    - PID file management
    - Graceful shutdown (SIGTERM)

[ ] .claude/tools/start_worker.sh
    - Check if running (pgrep)
    - Start in background (nohup)
    - Log to .data/worker.log

[ ] Tests:
    - Worker starts/stops
    - Processes queue events
    - Auto-restart works
```

**Day 5: Basic Hooks**
```
[ ] .claude/tools/hook_sessionend.py
    - Append to queue
    - Backup transcript

[ ] .claude/tools/hook_sessionstart.py
    - Read memory.json
    - Format preferences
    - Inject as context
    - Call start_worker.sh

[ ] .claude/settings.json
    - Add SessionStart hook
    - Add SessionEnd hook

[ ] Tests:
    - SessionEnd queues event
    - SessionStart loads preferences
    - Worker processes session_end event
```

### Week 2: Correction Detection

**Days 1-2: Stop Hook**
```
[ ] .claude/tools/hook_stop.py
    - Read last 3 messages
    - Detect correction keywords
    - Append to queue if detected

[ ] .claude/settings.json
    - Add Stop hook

[ ] Tests:
    - True positive: "No, use X instead"
    - False positive: "No bugs found" (shouldn't trigger)
    - Speed: <100ms
```

**Days 3-5: LLM Extraction**
```
[ ] amplicode/learning/extractor.py
    - extract_correction(transcript_snippet)
    - extract_session(full_transcript)
    - Defensive parsing
    - Retry logic

[ ] Integration with worker.py
    - Correction event → extract_correction
    - Session_end event → extract_session

[ ] Tests:
    - Extract 5 real corrections
    - Measure accuracy
    - Handle LLM failures
```

### Week 3: Validation

**Full Integration Test:**
```
1. Start session (SessionStart loads memory)
2. Have 5 correction interactions
3. Verify all queued
4. Wait for worker to process
5. Verify memory.json updated
6. Start new session
7. Verify preferences loaded
8. Verify Claude demonstrates awareness
```

**Performance Test:**
```
1. Generate 50 correction events
2. Measure queue throughput
3. Measure worker processing time
4. Verify no backlog
5. Measure hook latency (<100ms)
```

**Error Injection:**
```
1. Corrupt queue file
2. Corrupt memory.json
3. Kill worker mid-processing
4. LLM API failure
5. File permissions issue
6. Verify graceful degradation
```

---

## Trade-offs Analysis

### Background Processing vs SessionEnd-Only

**SessionEnd-Only (Simple):**
```
Pros:
+ Simplest possible (no queue, no worker, no background process)
+ Single point of extraction (SessionEnd)
+ No new infrastructure

Cons:
- Only learns at session end (too late for corrections)
- Misses highest-value signal (correction pattern)
- Can't do expensive analysis (blocks session end)
- No real-time learning
```

**Background Processing (Recommended):**
```
Pros:
+ Captures corrections in real-time
+ Zero latency impact (hooks just queue)
+ Can do expensive LLM analysis
+ Learns preferences for next session
+ Higher-value learning signal

Cons:
- More complex (~500 lines vs ~100 lines)
- Background process to manage
- Queue infrastructure needed
- Two tech stacks if we used Node (but we're using Python)
```

**Verdict:** Extra complexity justified because:
1. Correction pattern is 10x more valuable than session summaries
2. Background processing eliminates latency concerns
3. Still ruthlessly simple (file queue, single worker)
4. Complexity is modular (queue, worker, extractor - separate bricks)

### All Python vs Hybrid

**All Python (Chosen):**
```
Pros:
+ Single language (simpler)
+ Matches Amplifier (easier to learn from)
+ Can reuse defensive utilities
+ Team has Python expertise

Cons:
- Slower startup (~500ms vs ~100ms for Node)
- Higher memory (~50-100MB vs ~30-50MB)
- Event-driven code less natural
```

**Hybrid (Node.js worker):**
```
Pros:
+ Faster worker startup
+ Lower memory footprint
+ Event-driven I/O natural fit
+ Better async/await

Cons:
- Two languages to maintain
- Mixed tech stack
- Need to port defensive utilities
- Diverges from Amplifier
```

**Verdict:** All Python wins on simplicity. Performance difference doesn't matter for this workload (worker runs for hours, startup time irrelevant).

---

## Success Criteria

### Phase 1 (Week 1): Infrastructure Works
- [ ] Queue can handle 100 events/second
- [ ] Memory concurrent writes work (no corruption)
- [ ] Worker processes events reliably
- [ ] Worker auto-starts on SessionStart
- [ ] SessionEnd → queue → worker → memory flow complete

### Phase 2 (Week 2): Correction Detection Works
- [ ] Stop hook detects corrections (>80% true positive rate)
- [ ] Stop hook stays fast (<100ms)
- [ ] LLM extraction produces valid JSON (>95% parse rate)
- [ ] Extracted preferences make sense (manual review of 10 examples)

### Phase 3 (Week 3): Learning Loop Closes
- [ ] After 10 corrections in Session 1, all captured
- [ ] Session 2 loads preferences correctly
- [ ] Claude demonstrates awareness (mentions loaded preferences)
- [ ] User doesn't repeat corrections across sessions
- [ ] No slowdown in Claude Code responsiveness

### Long-term Success (1 month):
- [ ] 100+ corrections captured
- [ ] Memory.json has 20+ useful preferences
- [ ] Users report: "Claude remembers my preferences"
- [ ] Reduction in repeated corrections (measure: # corrections per session decreases over time)

---

## Files Reference

All paths relative to `/Volumes/code/personal/github/amplicode/`

### Configuration
- `.claude/settings.json` - Hook configurations

### Hooks (~90 lines total)
- `.claude/tools/hook_stop.py` - 30 lines
- `.claude/tools/hook_sessionend.py` - 20 lines
- `.claude/tools/hook_sessionstart.py` - 40 lines
- `.claude/tools/start_worker.sh` - 15 lines

### Core System (~450 lines total)
- `amplicode/learning/worker.py` - 150 lines
- `amplicode/learning/extractor.py` - 120 lines
- `amplicode/learning/memory.py` - 100 lines
- `amplicode/learning/queue.py` - 80 lines

### Data Files (runtime)
- `.data/learning_queue.jsonl`
- `.data/memory.json`
- `.data/worker.pid`
- `.data/worker.log`

### Tests (~300 lines total)
- `tests/learning/test_queue.py`
- `tests/learning/test_memory.py`
- `tests/learning/test_worker.py`
- `tests/learning/test_extractor.py`
- `tests/integration/test_full_flow.py`

**Total Implementation: ~840 lines**

---

## Key Takeaways

### 1. Background Processing Changes Everything
- Without it: Limited to SessionEnd extraction (too late)
- With it: Capture corrections in real-time (highest value)

### 2. Correction Pattern is Gold
- User explicitly rejects approach → preference learning
- Happens 5-10x per session (frequent enough)
- Far more valuable than generic session summaries

### 3. Ruthless Simplicity Still Applies
- File-based queue (no database)
- Single worker process (no orchestration)
- All Python (one language)
- ~500 lines total (modular bricks)

### 4. Hook Strategy is Critical
- Stop: Detect corrections (fast, frequent)
- SessionEnd: Full analysis (slow OK, once)
- SessionStart: Load context (slow OK, once)
- Skip: PostToolUse (too noisy), UserPromptSubmit (wrong timing)

### 5. Learning Loop Must Close
- Capture → Extract → Store → Load → Apply
- If Claude doesn't demonstrate awareness, learning didn't work
- Measure success: User stops repeating corrections

---

## Next Steps

1. **Review this recommendation** with team
2. **Decide:** Go with background processing or stick with SessionEnd-only?
3. **If approved:** Proceed with Week 1 implementation (queue + worker core)
4. **After Week 1:** Validate infrastructure before adding hooks
5. **After Week 2:** Test correction detection accuracy
6. **After Week 3:** Measure if learning loop works (user stops repeating corrections)

---

**This is the architecture that makes knowledge compound across sessions.**
