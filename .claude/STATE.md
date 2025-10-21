# Amplicode - Current State & Recommendations

**Date:** 2025-10-22
**Status:** Architecture Complete, Ready for Implementation
**Next:** Build the plugin (moonshot branch)

---

## What We've Built So Far

### ✅ Complete Architecture Documentation

1. **FINAL-ARCHITECTURE.md** (750 lines)
   - Plugin distribution model
   - Bash hooks (10-20ms target)
   - Global worker with self-watchdog
   - File locking for data safety
   - Multi-session handling
   - macOS M1 specifics
   - Sandbox compatibility plan

2. **global-vs-local-learning.md** (800 lines)
   - 3-level hierarchy: Global → Language → Project
   - Precedence rules (project wins)
   - Auto-promotion strategy (3+ occurrences)
   - Conflict resolution
   - User control mechanisms
   - Migration path from simple to complex

3. **amplifier-deep-analysis.md** (29KB)
   - Deep research on Microsoft Amplifier
   - 20+ specialized agents
   - Knowledge synthesis patterns
   - Memory system design
   - What to adopt vs avoid

4. **hook-architecture-recommendation.md** (20KB)
   - Background learning rationale
   - Correction pattern focus
   - 3-tier system (hooks → queue → worker)
   - Trade-offs analysis

5. **README.md**
   - Project overview
   - Plugin installation instructions
   - Usage examples
   - Implementation status

### ✅ Key Architectural Decisions Made

**Performance:**
- Bash hooks (NOT Python) → 15-30x faster
- Target: <50ms per hook call
- Background worker doesn't block Claude Code

**Data Safety:**
- Global single worker (NOT per-project)
- File locking with fcntl
- Atomic writes (tmp → rename)
- Multi-session safe

**Learning Strategy:**
- Focus on "correction pattern" (highest value)
- 3-level hierarchy (global/language/project)
- Auto-promotion when patterns emerge
- User transparency and control

**Distribution:**
- Claude Code plugin (easy installation)
- Auto-configured hooks
- Slash commands for control
- Team sharing via repository-level plugin

---

## What's NOT Built Yet (The Work Ahead)

### 🚧 Phase 1: Core Plugin Infrastructure

**Files to create:**
```
plugin/
├── plugin.json                    # Plugin manifest
├── README.md                      # Plugin-specific docs
├── hooks/
│   ├── hooks.json                 # Hook registration
│   ├── stop_hook.sh               # Detect corrections
│   ├── sessionend_hook.sh         # Queue session summary
│   └── sessionstart_hook.sh       # Load prefs, ensure worker
├── commands/
│   ├── status.md                  # /amplicode-status
│   ├── logs.md                    # /amplicode-logs
│   ├── restart.md                 # /amplicode-restart
│   └── preferences.md             # /amplicode-preferences (view learned)
├── scripts/
│   ├── learning_worker.py         # Main worker loop
│   ├── learning_extractor.py      # LLM extraction
│   ├── learning_memory.py         # Memory management
│   ├── health_monitor.py          # Self-watchdog
│   └── ensure_worker.sh           # Worker lifecycle
└── tests/
    ├── test_hook_performance.sh   # Verify <50ms
    ├── test_macos_setup.sh        # Prerequisites check
    ├── test_multi_session.sh      # Data safety
    └── test_sandbox.sh            # Sandbox compat
```

**Estimated: ~1000 lines of code total**

### 🚧 Phase 2: Learning Intelligence

**Scope detection:**
- When is preference global vs language vs project?
- LLM prompt design for classification
- Confidence scoring

**Auto-promotion:**
- Detect patterns across projects
- Promote to higher level when appropriate
- Deduplicate after promotion

**Conflict handling:**
- Detect conflicting preferences
- Keep project-specific when conflicts exist
- User notification

### 🚧 Phase 3: User Experience

**Slash commands:**
- /amplicode-status → worker health
- /amplicode-logs → view worker logs
- /amplicode-restart → restart worker
- /amplicode-preferences → view all learned
- /amplicode-edit-preference → modify/delete
- /amplicode-learn → explicit teaching

**Transparency:**
- Show why preference was applied
- Show confidence levels
- Show learning history

---

## Critical Path to MVP

### Week 1: Core Functionality

**Day 1-2: Plugin Structure**
- [ ] Create plugin.json manifest
- [ ] Create hooks.json registration
- [ ] Create basic README for plugin
- [ ] Test: Plugin installs successfully

**Day 3-4: Hooks**
- [ ] Implement stop_hook.sh (detect corrections)
- [ ] Implement sessionend_hook.sh (queue summary)
- [ ] Implement sessionstart_hook.sh (load prefs, start worker)
- [ ] Test: Hooks fire, queue appends

**Day 5-6: Worker**
- [ ] Implement learning_worker.py (main loop)
- [ ] Implement queue polling
- [ ] Implement heartbeat writing
- [ ] Implement self-watchdog
- [ ] Test: Worker processes queue

**Day 7: Integration**
- [ ] End-to-end test: correction → queue → worker → memory
- [ ] Performance test: hooks <50ms
- [ ] Multi-session test: no data corruption

### Week 2: Intelligence

**Day 8-9: LLM Extraction**
- [ ] Implement learning_extractor.py
- [ ] Design prompts for correction detection
- [ ] Design prompts for scope classification
- [ ] Test: Can extract preferences from corrections

**Day 10-11: Memory Management**
- [ ] Implement learning_memory.py
- [ ] File locking implementation
- [ ] Atomic writes
- [ ] Backup mechanism
- [ ] Test: Concurrent writes safe

**Day 12-13: Project-Level Learning**
- [ ] Write to <project>/.data/memory.json
- [ ] Read on SessionStart
- [ ] Inject into Claude Code context
- [ ] Test: Preferences persist across sessions

**Day 14: Polish**
- [ ] Error handling
- [ ] Logging
- [ ] Recovery mechanisms

### Week 3: User Control

**Day 15-16: Slash Commands**
- [ ] /amplicode-status (show worker health)
- [ ] /amplicode-logs (view logs)
- [ ] /amplicode-restart (restart worker)
- [ ] Test: Commands work, show correct info

**Day 17-18: Preference Management**
- [ ] /amplicode-preferences (view learned)
- [ ] /amplicode-edit-preference (modify/delete)
- [ ] /amplicode-learn (explicit teaching)
- [ ] Test: User can control learning

**Day 19-20: Documentation**
- [ ] Usage examples
- [ ] Troubleshooting guide
- [ ] Architecture diagrams

**Day 21: Release Prep**
- [ ] Final testing
- [ ] Demo video
- [ ] Submit to plugin marketplace

---

## Recommendations

### Start Simple, Iterate Fast

**Phase 1 (MVP):**
- Project-only learning (no global/language yet)
- Basic correction detection (keyword matching)
- Manual worker start (no auto-start in SessionStart yet)
- Simple memory.json schema

**Why:** Validates core loop works before adding complexity

**Phase 2 (Enhanced):**
- Add global preferences
- Add LLM-powered extraction
- Add auto-start in SessionStart
- Add slash commands

**Phase 3 (Full Vision):**
- Add language/platform context
- Add auto-promotion
- Add conflict detection
- Full user control

### Parallel Work Streams

**Can be done in parallel:**
1. Hooks implementation (bash scripting)
2. Worker implementation (Python)
3. Slash commands (markdown)
4. Test scripts (bash)

**Use agents for:**
- Implementing different hooks simultaneously
- Writing test scripts while building core
- Creating documentation while coding

### Quality Gates

**Before each merge:**
- [ ] Hook performance <50ms (measured)
- [ ] No data corruption in multi-session test
- [ ] Worker self-watchdog works (tested with stuck worker)
- [ ] All tests pass

### Risk Mitigation

**Biggest risks:**
1. **Hook performance** → Benchmark early, optimize if needed
2. **Data corruption** → Test multi-session scenario immediately
3. **Worker reliability** → Self-watchdog + heartbeat + recovery
4. **LLM extraction quality** → Start simple, iterate prompts

---

## Success Criteria

### Week 1 Success
- Plugin installs successfully
- Hooks fire and queue events
- Worker processes queue
- No crashes in 100-event session

### Week 2 Success
- Can detect a correction
- Can extract a preference
- Can write to memory.json
- Can load preferences on next session

### Week 3 Success
- User corrects something once
- Next session, Claude respects preference
- User can view learned preferences
- User can delete incorrect preferences

### Final Success
- User stops repeating themselves across sessions
- System learns context (project vs global)
- No performance degradation in Claude Code
- User trusts and relies on the system

---

## The Moonshot Vision

**Build the entire plugin in one intense push:**
- All hooks implemented
- Worker with self-watchdog
- LLM extraction working
- Memory management solid
- Slash commands functional
- Tests passing
- Ready for real usage

**Use parallel agents to:**
- Implement multiple components simultaneously
- Write tests while building
- Create docs while coding
- Maximize velocity

**Time estimate:** 1 week of intense work (if parallelized well)

**This is achievable because:**
- Architecture is complete
- Decisions are made
- Total code is ~1000 lines
- Components are modular
- Can use agents for parallelism

---

## Next Command

```bash
git checkout -b moonshot
```

**Then:** Build everything. Use agents. Go fast. Ship it.

**Remember:**
- Ruthless simplicity (150-line modules)
- No stubs or placeholders (everything works)
- Analysis-first (think before coding)
- Modular bricks (AI can regenerate)

**You can do this. The architecture is solid. The path is clear. Execute.**

---

## Repository

**Current:** https://github.com/yehosef/amplicode (main branch - docs only)
**Next:** https://github.com/yehosef/amplicode (moonshot branch - full implementation)

**When moonshot works:** Merge to main, publish plugin, change the world.
