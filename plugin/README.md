# Amplicode Plugin

**Background learning system for Claude Code** - learns from your corrections and preferences across sessions.

## What is Amplicode?

Amplicode captures your preferences when you correct Claude's suggestions and applies them automatically in future sessions. No more repeating the same corrections every day!

### Example

**Session 1:**
```
User: "Add authentication"
Claude: "I'll use JWT with Redis..."
User: "No, use local files instead."
Claude: "Got it, using local files..."
🧠 Amplicode learns: "This project prefers local files over Redis"
```

**Session 2 (next day):**
```
User: "Add user profiles"
Claude: "I'll set up local file-based sessions..." ← Already knows!
```

## Installation

### Step 1: Install Plugin

```
/plugin install amplicode
```

Then restart Claude Code.

### Step 2: Prerequisites

The plugin will auto-check on first run. If anything is missing:

```bash
# macOS
brew install python@3.11 jq
pip3 install anthropic psutil
```

That's it! The worker will auto-start on your first session.

## Usage

### Check Status

```
/amplicode-status
```

Shows worker health, queue size, and events processed.

### View Logs

```
/amplicode-logs
```

Options:
- `--lines=N` - Show N lines
- `--follow` - Stream logs in real-time
- `--level=ERROR` - Filter by log level

### Restart Worker

```
/amplicode-restart
```

Options:
- `--force` - Force kill and restart immediately

### View Learned Preferences

```
/amplicode-preferences
```

Shows all learned preferences organized by scope (Global/Language/Project).

Options:
- `--id=<id>` - Show specific preference
- `--all` - Show all preferences (default shows first 5)

## How It Works

### Architecture

```
Hooks (Bash, 10-20ms) → Queue (.jsonl) → Worker (Python, background) → Memory (.json)
```

1. **Hooks** detect corrections as they happen (fires after every Claude response)
2. **Queue** stores events to process later (doesn't block Claude Code)
3. **Worker** analyzes queue in background using LLM
4. **Memory** stores learned preferences for future sessions

### 3-Level Learning

Amplicode learns preferences at three levels:

1. **Global** (`~/.claude/global_memory.json`) - Universal patterns
   - "Always use descriptive variable names"
   - "Never use eval()"

2. **Language/Platform** (`~/.claude/context_memory.json`) - Context-specific
   - "Use pytest in Python projects"
   - "Use vitest in JavaScript projects"

3. **Project** (`<project>/.data/memory.json`) - Project-specific
   - "This legacy project uses files, not Redis"
   - "This team prefers OOP style"

**Precedence:** Project > Language > Global (most specific wins)

## Files & Locations

### Global (Shared Across All Projects)

```
~/.claude/
├── learning_worker.py          # Background worker
├── health_monitor.py           # Self-watchdog
├── learning_extractor.py       # LLM extraction
├── learning_memory.py          # Memory management
├── learning_queue.jsonl        # Event queue
├── worker.log                  # Worker logs
├── worker_heartbeat.json       # Health status
└── learning_worker.pid         # Process ID
```

### Per-Project

```
<your-project>/.data/
├── memory.json                 # Learned preferences
├── memory.json.backup          # Backup (auto-created)
└── memory.lock                 # File lock
```

## Performance

- **Hook latency:** 10-20ms per interaction (<50ms target)
- **Worker processing:** Background, doesn't block Claude Code
- **Total user-facing impact:** ~1-2 seconds per session

## Safety & Reliability

### Data Safety
- ✅ Global single worker (no multi-session conflicts)
- ✅ File locking (`fcntl.flock`) for concurrent access
- ✅ Atomic writes (tmp + rename)
- ✅ Automatic backups before each write

### Worker Reliability
- ✅ Self-watchdog (kills if stuck >2min)
- ✅ Heartbeat monitoring (writes every 1s)
- ✅ Auto-restart after 100 events (prevents memory leaks)
- ✅ Exponential backoff on crashes
- ✅ Comprehensive logging

### Privacy
- ✅ All data stored locally on your machine
- ✅ No data sent to external servers (except LLM extraction)
- ✅ You control what's learned (view/edit/delete preferences)

## Troubleshooting

### Worker Won't Start

```bash
# Check prerequisites
cd plugin/tests
./test_macos_setup.sh

# Check logs
/amplicode-logs --level=ERROR

# Force restart
/amplicode-restart --force
```

### Performance Issues

```bash
# Check hook performance
cd plugin/tests
./test_hook_performance.sh

# If hooks are slow (>50ms), check if jq is installed:
brew install jq
```

### Data Corruption

Worker automatically recovers from corrupted memory files using backups. If issues persist:

```bash
# Check worker logs
/amplicode-logs --level=ERROR

# Restart worker
/amplicode-restart
```

## Development

### Run Tests

```bash
cd plugin/tests

# All tests
./run_all_tests.sh

# Individual tests
./test_macos_setup.sh           # Prerequisites
./test_hook_performance.sh      # Performance
./test_multi_session.sh         # Data safety
./test_sandbox.sh               # Sandbox compat
```

### Project Structure

```
plugin/
├── plugin.json                 # Plugin manifest
├── README.md                   # This file
├── hooks/
│   ├── hooks.json              # Hook registration
│   ├── stop_hook.sh            # Detect corrections
│   ├── sessionend_hook.sh      # Queue session summary
│   └── sessionstart_hook.sh    # Load prefs, start worker
├── commands/
│   ├── status.md               # /amplicode-status
│   ├── logs.md                 # /amplicode-logs
│   ├── restart.md              # /amplicode-restart
│   └── preferences.md          # /amplicode-preferences
├── scripts/
│   ├── learning_worker.py      # Main worker loop
│   ├── learning_extractor.py   # LLM extraction
│   ├── learning_memory.py      # Memory management
│   └── health_monitor.py       # Self-watchdog
└── tests/
    ├── test_hook_performance.sh
    ├── test_macos_setup.sh
    ├── test_multi_session.sh
    └── test_sandbox.sh
```

## Contributing

See main repository: https://github.com/yehosef/amplicode

## License

MIT

## Acknowledgments

Inspired by Microsoft's [Amplifier](https://github.com/microsoft/amplifier) research project.
