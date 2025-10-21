# Amplicode

**Background learning system for Claude Code** - inspired by Microsoft Amplifier

> **Status:** Architecture & Documentation Complete | Plugin Implementation In Progress
> **Distribution:** Claude Code Plugin (coming soon to plugin marketplace)

## What is Amplicode?

Amplicode is a metacognitive enhancement system for Claude Code that learns from your interactions and improves over time. Unlike traditional AI assistants that start fresh each session, Amplicode captures your preferences, corrections, and patterns to provide increasingly personalized assistance.

## Core Features

### 🎯 Correction Pattern Learning
Amplicode focuses on the highest-value learning signal: when you correct Claude's approach. If Claude suggests JWT with Redis and you say "use local files instead," Amplicode learns your preference for file-based solutions.

### ⚡ Non-Blocking Architecture
Built for performance with:
- **Bash hooks** (10-20ms overhead per interaction)
- **Background worker** (processes learning without blocking)
- **Global single worker** (prevents data corruption across multiple Claude Code sessions)

### 🔄 Continuous Learning
- Captures corrections in real-time via hooks
- Processes insights asynchronously
- Loads preferences at session start
- Builds cumulative knowledge across all sessions

## Architecture

```
Hooks (Bash) → Queue (.jsonl) → Worker (Python) → Memory (.json)
  10-20ms         Append-only     LLM extraction    Preferences
```

**3-Tier System:**
1. **Hooks** (Bash): Detect events, queue instantly (~10-20ms)
2. **Queue** (JSONL): Durable append-only log
3. **Worker** (Python): Global background process, LLM-powered extraction

**Key Design Principles:**
- **Ruthless Simplicity**: Simplest thing that works
- **Modular Bricks**: ~150 line modules AI can regenerate
- **Zero-BS Principle**: No stubs or placeholders
- **Analysis-First**: Think before implementing

## Differences from Microsoft Amplifier

| Aspect | Amplifier | Amplicode |
|--------|-----------|-----------|
| **Learning Location** | Stop hook (fires 50-100x/session) | Background worker |
| **Hook Language** | Python (~250ms overhead) | Bash (~10ms overhead) |
| **Worker Scope** | Per-project | Global single instance |
| **Primary Focus** | Knowledge synthesis | Correction pattern |
| **Performance** | 25-35s hook overhead | 1-2s hook overhead |

## Platform Support

**Designed for:** macOS M1 (documented specifics)
**Tested on:** macOS M1
**Theoretical:** Linux (file locking compatible), Windows (untested)

## Documentation

- **[CLAUDE.md](CLAUDE.md)** - Primary guidance for Claude Code
- **[.claude/notes/FINAL-ARCHITECTURE.md](.claude/notes/FINAL-ARCHITECTURE.md)** - Production architecture
- **[.claude/notes/amplifier-deep-analysis.md](.claude/notes/amplifier-deep-analysis.md)** - Research on Amplifier
- **[.claude/notes/hook-architecture-recommendation.md](.claude/notes/hook-architecture-recommendation.md)** - Architecture rationale

## Quick Start

### Installation

**Step 1: Install Plugin (Coming Soon)**
```
# In Claude Code
/plugin install amplicode

# Restart Claude Code
# Done! Hooks auto-register, worker auto-starts on first session
```

**Step 2: Prerequisites (Auto-checked on first run)**
```bash
# macOS M1
brew install python@3.11 jq
pip3 install anthropic psutil
```

The plugin will notify you if prerequisites are missing.

### Usage

**Check Status:**
```
/amplicode-status
```

**View Logs:**
```
/amplicode-logs
```

**Restart Worker:**
```
/amplicode-restart
```

**How It Works:**
1. Make corrections during your session (e.g., "No, use files instead of Redis")
2. Worker learns your preferences in the background
3. Next session loads your preferences automatically
4. Claude adapts to your style over time

## Implementation Status

**Current Phase:** Architecture & Documentation ✅

**Distribution Model:** Claude Code Plugin

**Next Phase:** Plugin Implementation (Week 1)
- [ ] Create plugin structure (hooks/, commands/, scripts/)
- [ ] Bash hooks with auto-install logic
- [ ] Global worker with self-watchdog
- [ ] Slash commands (/amplicode-status, /amplicode-logs, /amplicode-restart)
- [ ] File locking and atomic writes
- [ ] macOS M1 test scripts
- [ ] Plugin manifest (plugin.json)

## Key Technical Decisions

1. **Bash hooks** (not Python) - 15-30x faster
2. **Global worker** (not per-project) - Prevents data corruption
3. **Correction pattern** - Highest-value learning signal
4. **Background processing** - No blocking on LLM calls
5. **File-based everything** - JSONL queue, JSON memory, file locks

## Monitoring & Recovery

Built-in health monitoring:
- **Heartbeat** (written every 1s)
- **Self-watchdog** (kills stuck worker after 2min)
- **Exponential backoff** (prevents crash loops)
- **CLI commands** (status, logs, restart)

## Contributing

Built following Amplifier's philosophy:
- Document everything
- Analysis before implementation
- Modular, regenerable components
- Learn from real usage

## License

[To be determined]

## Acknowledgments

Inspired by Microsoft's [Amplifier](https://github.com/microsoft/amplifier) research project. Special thanks to the Amplifier team for pioneering agentic development patterns.
