# Final Architecture: Background Learning System
**Date:** 2025-10-22 (Updated for Plugin Distribution)
**Status:** APPROVED FOR IMPLEMENTATION
**Platform:** macOS M1 (with notes for cross-platform)
**Distribution:** Claude Code Plugin

---

## Plugin Distribution Model

Amplicode is distributed as a **Claude Code plugin**, enabling:
- ✅ **One-command installation** - `/plugin install amplicode`
- ✅ **Auto-configuration** - Hooks register automatically
- ✅ **Team sharing** - Repository-level plugin for entire team
- ✅ **Slash commands** - `/amplicode-status`, `/amplicode-restart`, `/amplicode-logs`
- ✅ **Global worker** - Single background process serves all Claude Code sessions

**Why Plugin vs System Install?**
- Easier installation (no manual file copying)
- Better team collaboration (auto-installed for all team members)
- Integrated with Claude Code lifecycle
- Standard distribution mechanism

---

## Critical Decisions from Code Review

### 1. Bash Hooks (NOT Python)
**Reason:** Python startup = 250-350ms → 25-35s overhead per session
**Solution:** Bash = 10-20ms → 1-2s overhead (15-30x faster)

### 2. Global Single Worker (NOT Per-Project)
**Reason:** Multiple sessions → multiple workers → data corruption
**Solution:** One global worker for all projects

### 3. Heartbeat + Monitoring
**Reason:** Worker can get stuck, user needs to know
**Solution:** Heartbeat every 1s + `claude-learning status` command

### 4. File Locking Everywhere
**Reason:** Concurrent writes will corrupt data
**Solution:** `flock` for atomic operations

---

## Architecture Overview

```
┌────────────────────────────────────────────────────────────┐
│  Multiple Claude Code Sessions                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                │
│  │Project A │  │Project A │  │Project B │                │
│  │Window 1  │  │Window 2  │  │Window 1  │                │
│  └─────┬────┘  └─────┬────┘  └─────┬────┘                │
│        │             │             │                       │
│        │ Bash hooks (10-20ms each) │                       │
│        ▼             ▼             ▼                       │
└────────────────────────────────────────────────────────────┘
                       │
                       │ Append with flock
                       ▼
┌────────────────────────────────────────────────────────────┐
│  Global Queue: ~/.claude/learning_queue.jsonl              │
│  {"project":"/path/to/A","type":"stop",...}               │
│  {"project":"/path/to/A","type":"correction",...}         │
│  {"project":"/path/to/B","type":"stop",...}               │
└────────────────────────────────────────────────────────────┘
                       │
                       │ Poll every 1s
                       ▼
┌────────────────────────────────────────────────────────────┐
│  Global Worker Process                                     │
│  - PID: ~/.claude/learning_worker.pid                     │
│  - Heartbeat: ~/.claude/worker_heartbeat.json (every 1s)  │
│  - Logs: ~/.claude/worker.log                             │
│  - Self-watchdog: Kills itself if stuck >2min             │
│  - Exponential backoff on restart                         │
└────────────────────────────────────────────────────────────┘
                       │
         ┌─────────────┼─────────────┐
         ▼             ▼             ▼
    Project A/    Project A/    Project B/
    .data/        .data/        .data/
    memory.json   (shared)      memory.json
    (with flock)                (with flock)
```

---

## Component Details

### 1. Bash Hooks (~30 lines each)

**Plugin Location:** `amplicode-plugin/hooks/`
**Registered via:** `hooks/hooks.json` (auto-registered when plugin installed)

**Files:**
- `stop_hook.sh` - Detects corrections, queues (fires 50-100x/session)
- `sessionend_hook.sh` - Queues session analysis (fires 1x/session)
- `sessionstart_hook.sh` - Loads preferences, ensures worker running (fires 1x/session)

**Plugin hooks.json:**
```json
{
  "stop": {
    "command": "bash $PLUGIN_DIR/hooks/stop_hook.sh",
    "description": "Queue potential corrections for background learning",
    "timeout": 5000
  },
  "sessionEnd": {
    "command": "bash $PLUGIN_DIR/hooks/sessionend_hook.sh",
    "description": "Queue session summary for analysis",
    "timeout": 5000
  },
  "sessionStart": {
    "command": "bash $PLUGIN_DIR/hooks/sessionstart_hook.sh",
    "description": "Load preferences and ensure worker is running",
    "timeout": 10000
  }
}
```

**Example: stop_hook.sh**
```bash
#!/bin/bash
set -euo pipefail

GLOBAL_QUEUE="${HOME}/.claude/learning_queue.jsonl"
PROJECT_ROOT="${PWD}"
TIMESTAMP=$(date +%s)

# Create queue if doesn't exist
mkdir -p "$(dirname "$GLOBAL_QUEUE")"
touch "$GLOBAL_QUEUE"

# Generate JSON (use jq if available, fallback to Python)
if command -v jq &> /dev/null; then
    EVENT_JSON=$(jq -n \
        --arg project "$PROJECT_ROOT" \
        --arg timestamp "$TIMESTAMP" \
        '{project: $project, event_type: "stop", timestamp: ($timestamp | tonumber)}')
else
    # Fallback to Python
    EVENT_JSON=$(python3 -c "import json; print(json.dumps({
        'project': '$PROJECT_ROOT',
        'event_type': 'stop',
        'timestamp': $TIMESTAMP
    }))")
fi

# Atomic append with file lock
{
    flock -x 200
    echo "$EVENT_JSON" >> "$GLOBAL_QUEUE"
} 200>/tmp/claude_learning_queue.lock

# Performance: 10-20ms (vs 250-350ms for Python)
```

**Example: sessionstart_hook.sh (Plugin Auto-Install)**
```bash
#!/bin/bash
set -euo pipefail

WORKER_PATH="${HOME}/.claude/learning_worker.py"
PLUGIN_WORKER="${PLUGIN_DIR}/scripts/learning_worker.py"

# First-time setup: Copy worker to global location
if [ ! -f "$WORKER_PATH" ]; then
    echo "Installing Amplicode worker..."
    cp "$PLUGIN_WORKER" "$WORKER_PATH"
    chmod +x "$WORKER_PATH"
fi

# Ensure worker is running (non-blocking)
if ! pgrep -f "learning_worker.py" > /dev/null; then
    nohup "$WORKER_PATH" > ~/.claude/worker.log 2>&1 &
    echo "Started Amplicode worker (PID $!)"
fi

# Load preferences into environment for this session
# (Claude Code will see these as context)
if [ -f ".data/memory.json" ]; then
    # Export preferences as env vars or write to .claude/context
    python3 -c "
import json, os
with open('.data/memory.json') as f:
    data = json.load(f)
    # Could export to env, or write to context file
    print(f'Loaded {len(data.get(\"preferences\", []))} preferences')
"
fi
```

**Why SessionStart Installs Worker:**
- Hook fires once per session (low frequency)
- 10s timeout allows for setup work
- Worker installed globally (persists across all projects)
- Non-blocking start via `nohup` (doesn't wait for worker)

### 2. Global Queue

**Location:** `~/.claude/learning_queue.jsonl`

**Why global?**
- Single worker for all projects (avoids multi-worker conflicts)
- Each event includes project path
- Worker switches to project directory when processing

**Format:**
```jsonl
{"project":"/Users/you/proj1","event_type":"stop","timestamp":1729530000}
{"project":"/Users/you/proj1","event_type":"correction","offset":42,"timestamp":1729530005}
{"project":"/Users/you/proj2","event_type":"stop","timestamp":1729530010}
```

**Rotation:**
- Auto-archives when >10,000 events
- Compresses old archives with gzip
- Keeps last 7 days of archives

### 3. Global Worker (~200 lines)

**Location:** `~/.claude/learning_worker.py`

**Lifecycle:**
```python
while True:
    # 1. Write heartbeat (every iteration)
    write_heartbeat()

    # 2. Poll queue
    events = poll_queue_streaming(limit=10)

    # 3. Process each event
    for event in events:
        project = event['project']
        os.chdir(project)  # Switch to project

        with timeout(60):  # Max 60s per event
            process_event(event)

        write_heartbeat()

    # 4. Sleep
    time.sleep(1)

    # 5. Auto-restart after 100 events (prevent memory leaks)
    if events_processed >= 100:
        sys.exit(0)  # SessionStart will restart
```

**Self-Watchdog:**
```python
class HealthMonitor:
    def __init__(self):
        self.last_activity = time.time()

        # Start watchdog thread
        threading.Thread(target=self._watchdog, daemon=True).start()

    def _watchdog(self):
        while True:
            time.sleep(10)

            if time.time() - self.last_activity > 120:  # 2min stuck
                log_error("Worker stuck, forcing restart")
                dump_debug_info()
                os._exit(1)  # Force exit
```

**Crash Protection:**
```python
def should_restart_worker():
    state = load_restart_state()

    # Exponential backoff: 2^n seconds, max 1 hour
    if time.time() < state.get('backoff_until', 0):
        return False  # In backoff period

    # Give up after 5 attempts
    if state['restart_count'] > 5:
        log_error("Worker crashed 5 times, giving up")
        return False

    # Update backoff
    state['restart_count'] += 1
    state['backoff_until'] = time.time() + (2 ** state['restart_count'])
    save_restart_state(state)

    return True
```

### 4. User Commands

**Option A: Slash Commands (Plugin Provides)**

**/amplicode-status**
```
🟢 Worker healthy

   Status: processing
   Queue size: 3 events
   Processed: 47 events (this session)
   Last heartbeat: 2s ago
```

**/amplicode-logs**
```
2025-10-22 14:30:00 [INFO] Worker started (PID 1234)
2025-10-22 14:30:01 [INFO] Processing correction event
2025-10-22 14:30:06 [INFO] Extracted preference: file-based over Redis
2025-10-22 14:30:07 [INFO] Updated memory.json for project /Users/you/proj1
```

**/amplicode-restart**
```
Stopping worker (PID 1234)...
Worker stopped
Starting worker...
Worker started (PID 5678)
```

**Option B: CLI Commands (Optional Install)**

For users who want terminal access:
```bash
# Install CLI wrapper (optional)
$ ln -s ~/.claude/amplicode_cli.sh /usr/local/bin/claude-learning

# Then use from terminal
$ claude-learning status
$ claude-learning logs --follow
$ claude-learning restart
```

**Plugin Structure:**
```
amplicode-plugin/
├── hooks/
│   ├── hooks.json              # Auto-registered hooks
│   ├── stop_hook.sh
│   ├── sessionend_hook.sh
│   └── sessionstart_hook.sh
├── commands/
│   ├── status.md               # /amplicode-status
│   ├── logs.md                 # /amplicode-logs
│   └── restart.md              # /amplicode-restart
├── scripts/
│   ├── learning_worker.py      # Copied to ~/.claude/ on first use
│   └── ensure_worker.sh        # Worker lifecycle management
└── README.md
```

---

## Data Safety Guarantees

### Multiple Sessions
**Problem:** User opens 3 Claude Code windows in same project
**Solution:** Global worker with file locking

```bash
# Session 1 SessionStart
flock -n ~/.claude/worker.lock start_worker_if_needed.sh
# → Acquires lock, starts worker

# Session 2 SessionStart (same time)
flock -n ~/.claude/worker.lock start_worker_if_needed.sh
# → Can't acquire lock (non-blocking), exits immediately
# → Reuses Session 1's worker

# Session 3 SessionStart
# → Also reuses existing worker

# Result: Only ONE worker running
```

### Concurrent memory.json Writes
**Problem:** Worker processing events from Project A and B simultaneously

**Solution:** File locking per project
```python
def write_memory(project_path, data):
    memory_file = f"{project_path}/.data/memory.json"
    lock_file = f"{project_path}/.data/memory.lock"

    with open(lock_file, 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)  # Block until available

        # Read current memory
        with open(memory_file, 'r') as f:
            memory = json.load(f)

        # Merge new data
        memory['preferences'].append(data)

        # Write to temp, then atomic rename
        with open(f"{memory_file}.tmp", 'w') as f:
            json.dump(memory, f, indent=2)

        os.replace(f"{memory_file}.tmp", memory_file)

        fcntl.flock(lock, fcntl.LOCK_UN)
```

### Worker Crashes
**Problem:** Worker crashes mid-processing

**What happens:**
1. Event still in queue (not removed until processed)
2. Next SessionStart detects no worker
3. Checks restart backoff
4. Restarts worker
5. Worker re-processes event (with idempotency check)

**Maximum delay:** Until next session starts
**Data lost:** None (queue persisted, transcripts backed up)

---

## Performance Characteristics

### Hook Latency (Per 100-event Session)

| Hook Type | Time/Call | 100 Calls | User Impact |
|-----------|-----------|-----------|-------------|
| **Bash (recommended)** | 10-20ms | 1-2s | ✅ Acceptable |
| Python | 250-350ms | 25-35s | ❌ Unacceptable |
| Node.js | 50-80ms | 5-8s | ⚠️ Marginal |

**Conclusion:** Bash hooks are 15-30x faster than Python.

### Worker Processing

| Operation | Time | Frequency |
|-----------|------|-----------|
| Queue poll | <10ms | Every 1s |
| Correction extraction (LLM) | 5-10s | Per correction (~5-10/session) |
| Session analysis (LLM) | 10-30s | Per session (1/session) |
| Memory write | <50ms | Per learning |

**Total overhead per session:**
- Hook latency: 1-2s (Bash)
- Worker processing: 0s (parallel, doesn't block)
- **Total user-facing impact: 1-2 seconds**

---

## macOS M1 Specifics

### Prerequisites

```bash
# Python 3.11+ (via Homebrew)
brew install python@3.11

# jq (for fast JSON in hooks)
brew install jq

# Python dependencies
pip3 install anthropic psutil
```

### Known Platform Issues

**1. Multiple Python Versions**
```bash
# System Python (3.9) vs Homebrew (3.11+)
/usr/bin/python3 --version  # 3.9.x
/opt/homebrew/bin/python3 --version  # 3.11.x

# Solution: Use Homebrew Python explicitly
#!/opt/homebrew/bin/python3
```

**2. Advisory Locks Not Mandatory**
- macOS `fcntl.flock()` is advisory only
- Other processes CAN read/write without checking lock
- **Solution:** Use both locks + atomic renames (already implemented)

**3. Case-Insensitive Filesystem**
- `Queue.jsonl` == `queue.jsonl` on macOS
- **Solution:** Always use lowercase filenames

**4. File Permissions**
```bash
# macOS default umask: 022
# Solution: Explicitly set permissions
mkdir -p ~/.claude
chmod 700 ~/.claude  # Owner only
```

### Verification Script

```bash
#!/bin/bash
# test_macos_setup.sh

echo "=== macOS M1 Setup Verification ==="

# Check Python
python3 --version | grep "3.11" && echo "✅ Python 3.11+" || echo "❌ Need Python 3.11+"

# Check jq
command -v jq &> /dev/null && echo "✅ jq installed" || echo "⚠️  jq missing (optional)"

# Check dependencies
python3 -c "import anthropic, psutil" 2>/dev/null && echo "✅ Python deps" || echo "❌ Run: pip3 install anthropic psutil"

# Check file locking
python3 << 'EOF'
import fcntl
with open('/tmp/test_lock', 'w') as f:
    fcntl.flock(f.fileno(), fcntl.LOCK_EX)
    print("✅ File locking works")
EOF

echo "=== Setup Complete ==="
```

---

## Sandbox Mode Compatibility

### Status: **UNKNOWN - REQUIRES TESTING**

**Test Checklist:**
- [ ] Can write to `.data/` directory?
- [ ] Can spawn background processes?
- [ ] Do background processes persist after hook exits?
- [ ] Does file locking work?
- [ ] Can access network (LLM API)?

**Graceful Degradation:**
```bash
# If in sandbox, disable background processing
if [ -n "${CLAUDE_SANDBOX_MODE:-}" ]; then
    echo "⚠️  Sandbox mode detected - background learning disabled"
    exit 0
fi
```

**Test Script:**
```bash
#!/bin/bash
# test_sandbox.sh

echo "=== Sandbox Compatibility Test ==="

# Test 1: Write to .data/
mkdir -p .data && echo "test" > .data/test.txt && echo "✅ Can write" || echo "❌ Cannot write"

# Test 2: Spawn subprocess
python3 -c "import subprocess; subprocess.Popen(['sleep', '1'])" && echo "✅ Can spawn" || echo "❌ Cannot spawn"

# Test 3: Background persistence
python3 -c "import subprocess; p = subprocess.Popen(['sleep', '5']); print(p.pid)" > .data/test_pid
sleep 2
ps -p $(cat .data/test_pid) > /dev/null && echo "✅ Persists" || echo "❌ Killed"

# Test 4: Network
python3 -c "import urllib.request; urllib.request.urlopen('https://api.anthropic.com', timeout=5)" 2>/dev/null && echo "✅ Network" || echo "❌ Network blocked"
```

---

## Failure Modes & Recovery

### Worker Stuck

**Detection:**
```bash
$ claude-learning status
🔴 Worker STUCK (last heartbeat 35s ago)

   PID: 1234
   Status: processing
   Current event: {"type":"correction",...}

To force restart: claude-learning restart --force
```

**Recovery:**
```bash
$ claude-learning restart --force
Stopping worker (PID 1234)...
Force killed
Starting worker...
Worker started (PID 5678)
```

### Memory.json Corrupted

**Symptoms:** Worker crashes with `JSONDecodeError`

**Recovery:**
```bash
# Automatic: Worker loads from backup
Worker: Corrupted memory.json, loading from backup...
Loaded memory.json.backup (loss: <1 session)
```

### Queue Growing (Not Processing)

**Detection:**
```bash
$ wc -l ~/.claude/learning_queue.jsonl
5000 ~/.claude/learning_queue.jsonl  # Should be <100

$ claude-learning status
Queue size: 5000 events  # Stuck!
```

**Recovery:**
```bash
# Check worker
$ claude-learning status
# If stuck, restart
$ claude-learning restart

# If worker processing but slow (LLM timeouts)
$ claude-learning logs | grep ERROR
# Look for APITimeoutError

# If persistent, archive queue and start fresh
$ mv ~/.claude/learning_queue.jsonl ~/.claude/learning_queue.jsonl.backup
$ touch ~/.claude/learning_queue.jsonl
$ claude-learning restart
```

---

## Implementation Files

### Plugin Structure
```
amplicode-plugin/
├── hooks/
│   ├── hooks.json                 (25 lines) - Hook registration
│   ├── stop_hook.sh               (30 lines) - Bash, fires 50-100x/session
│   ├── sessionend_hook.sh         (20 lines) - Bash, fires 1x/session
│   └── sessionstart_hook.sh       (50 lines) - Bash, fires 1x/session, installs worker
│
├── commands/
│   ├── status.md                  (30 lines) - /amplicode-status slash command
│   ├── logs.md                    (30 lines) - /amplicode-logs slash command
│   └── restart.md                 (30 lines) - /amplicode-restart slash command
│
├── scripts/
│   ├── learning_worker.py         (200 lines) - Main worker loop
│   ├── learning_extractor.py      (100 lines) - LLM extraction logic
│   ├── learning_memory.py         (50 lines) - Safe memory writes with locking
│   └── ensure_worker.sh           (30 lines) - Worker lifecycle management
│
├── tests/
│   ├── test_hook_performance.sh   (50 lines) - Verify <50ms per hook call
│   ├── test_macos_setup.sh        (50 lines) - macOS M1 prerequisites
│   ├── test_sandbox.sh            (50 lines) - Sandbox compatibility
│   └── test_multi_session.sh      (50 lines) - Multiple Claude Code windows
│
├── plugin.json                    (20 lines) - Plugin manifest
└── README.md                      (100 lines) - Installation & usage
```

**Total: ~915 lines of code**

### Global Runtime Files (Created by Plugin)
```
~/.claude/
├── learning_worker.py             (copied from plugin on first SessionStart)
├── learning_queue.jsonl           (created automatically)
├── worker.log                     (worker stdout/stderr)
├── worker_heartbeat.json          (updated every 1s)
└── learning_worker.pid            (worker process ID)
```

### Per-Project Data
```
<project>/.data/
├── memory.json                    (learned preferences for this project)
├── memory.json.backup             (backup before each write)
└── memory.lock                    (file lock for concurrent safety)
```

---

## Comparison: Before vs After Code Review

### Original Design
```
❌ Python hooks (250-350ms) = 25-35s overhead
❌ Per-project workers = data corruption risk
❌ No monitoring = can't tell if working
✅ Background processing = good idea
```

### Final Design
```
✅ Bash hooks (10-20ms) = 1-2s overhead (15-30x faster)
✅ Global worker = no multi-session conflicts
✅ Heartbeat + CLI = full monitoring
✅ File locking = data safety
✅ Self-watchdog = auto-recovery
```

**Result:** Production-ready, safe, fast.

---

## Next Steps

1. **✅ Create GitHub repo** - https://github.com/yehosef/amplicode
2. **Implement Plugin (Week 1)**:
   - Create plugin structure (hooks/, commands/, scripts/)
   - Implement bash hooks with auto-install logic
   - Implement global worker with self-watchdog
   - Create slash commands (/amplicode-status, /amplicode-logs, /amplicode-restart)
   - Write plugin.json manifest
3. **Test on macOS M1**:
   - Multi-session scenario (multiple Claude Code windows)
   - Worker crash/restart recovery
   - Hook performance benchmarks (<50ms target)
4. **Test in sandbox** (when Claude Code sandbox mode available)
5. **Publish Plugin**:
   - Submit to plugin marketplace
   - Create installation documentation
   - Demo video showing correction pattern learning

---

## Success Criteria

**Week 1:**
- [ ] Bash hooks <50ms per call
- [ ] Global worker handles multiple sessions safely
- [ ] `claude-learning status` shows health
- [ ] Zero data corruption in multi-session test

**Week 2:**
- [ ] Correction detection >80% accuracy
- [ ] LLM extraction works reliably
- [ ] Memory.json updating correctly

**Week 3:**
- [ ] After 10 corrections in Session 1, Session 2 shows learned preferences
- [ ] User stops repeating corrections across sessions
- [ ] No slowdown in Claude Code responsiveness

**This is the architecture that will ship.**
