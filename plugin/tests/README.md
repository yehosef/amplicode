# Amplicode Plugin Test Suite

This directory contains test scripts to validate the Amplicode plugin functionality, performance, and compatibility.

## Test Scripts

### 1. test_hook_performance.sh
**Purpose:** Verify hooks execute in <50ms

**What it tests:**
- Measures execution time of each hook (stop, sessionend, sessionstart)
- Runs each hook 10 times
- Reports average, min, max execution times
- FAILS if average execution time exceeds 50ms

**Why it's critical:**
- Hooks fire 50-100+ times per session
- Slow hooks directly impact Claude Code responsiveness
- Performance target: <50ms per call (15-30x faster than Python)

**Run:**
```bash
./test_hook_performance.sh
```

**Expected output:**
```
=== Hook Performance Test ===
Target: <50ms per hook call
Running 10 iterations per hook...

Testing: stop_hook.sh
  Iterations: 10
  Average: 15ms
  Min: 12ms
  Max: 23ms
  ✅ PASS: Average 15ms <= 50ms target

Testing: sessionend_hook.sh
  Iterations: 10
  Average: 18ms
  Min: 14ms
  Max: 25ms
  ✅ PASS: Average 18ms <= 50ms target

Testing: sessionstart_hook.sh
  Iterations: 10
  Average: 45ms
  Min: 38ms
  Max: 52ms
  ✅ PASS: Average 45ms <= 50ms target

=== Performance Test Summary ===
✅ All hooks meet performance target (<50ms)
```

---

### 2. test_macos_setup.sh
**Purpose:** Verify prerequisites on macOS M1

**What it tests:**
- Python 3.11+ installation
- jq installation (optional but recommended)
- Required Python packages (anthropic, psutil)
- File locking functionality (fcntl)
- ~/.claude/ directory permissions
- /tmp/ access
- Process spawning capability
- Date command
- Bash version
- flock command

**Why it's critical:**
- Validates environment before plugin installation
- Prevents runtime failures due to missing dependencies
- Ensures all required tools are available

**Run:**
```bash
./test_macos_setup.sh
```

**Expected output:**
```
=== macOS M1 Setup Verification ===

Python 3.11+: ✅ Python 3.11.5
jq (optional): ✅ jq-1.7
anthropic package: ✅ Version 0.8.1
psutil package: ✅ Version 5.9.5
File locking (fcntl): ✅ Working
~/.claude/ directory: ✅ Exists and writable (700)
/tmp/ access: ✅ Can write to /tmp/
Process spawning: ✅ Can spawn subprocesses
Date command: ✅ Working (timestamp: 1729612345)
Bash version: ✅ Bash 5.2
flock command: ✅ Available

=== Setup Summary ===
✅ All prerequisites met - Amplicode ready to run
```

**If tests fail:**
```bash
# Install missing dependencies
brew install python@3.11 jq util-linux
pip3 install anthropic psutil
```

---

### 3. test_multi_session.sh
**Purpose:** Verify data safety with multiple concurrent sessions

**What it tests:**
- Simulates 3 concurrent Claude Code sessions
- Each session writes 20 events to the queue
- Verifies no data corruption
- Verifies all events were written
- Verifies no duplicate events
- Verifies no missing events
- Tests file locking prevents race conditions

**Why it's critical:**
- Users often have multiple Claude Code windows open
- Without proper locking, concurrent writes corrupt data
- Data safety is non-negotiable

**Run:**
```bash
./test_multi_session.sh
```

**Expected output:**
```
=== Multi-Session Data Safety Test ===
Simulating 3 concurrent sessions writing to queue...

Configuration:
  Sessions: 3
  Events per session: 20
  Expected total events: 60

Starting concurrent sessions...
✅ All sessions completed

=== Verification ===
Queue file exists: ✅
Event count: ✅ 60 events (expected 60)
JSON validity: ✅ All events are valid JSON
Duplicate check: ✅ No duplicate events
Session completeness: ✅ All sessions wrote expected events
Sequence integrity: ✅ All sequences intact

=== File Locking Test ===
Testing concurrent lock acquisition...
✅ File locking working correctly (30/30 writes)

=== Multi-Session Test Summary ===
✅ All data safety tests passed

Results:
  - No data corruption
  - No missing events
  - No duplicate events
  - File locking prevents race conditions
  - Safe for concurrent Claude Code sessions
```

---

### 4. test_sandbox.sh
**Purpose:** Test sandbox mode compatibility

**What it tests:**
- Write permissions to .data/
- Write permissions to ~/.claude/
- Write permissions to /tmp/
- Subprocess spawning
- Background process persistence
- File locking (fcntl and flock)
- Network access
- Python package availability
- Environment variable access

**Why it's critical:**
- Claude Code may run in sandbox mode
- Need to know which features work/don't work
- Enables graceful degradation strategy

**Run:**
```bash
./test_sandbox.sh

# Or test sandbox behavior explicitly
CLAUDE_SANDBOX_MODE=1 ./test_sandbox.sh
```

**Expected output (normal mode):**
```
=== Sandbox Mode Compatibility Test ===

ℹ️  Running in NORMAL MODE
   (Set CLAUDE_SANDBOX_MODE=1 to test sandbox behavior)

=== Capability Tests ===
Write to .data/: ✅ Can write
Write to ~/.claude/: ✅ Can write
Write to /tmp/: ✅ Can write
Spawn subprocess: ✅ Can spawn
Background persistence: ✅ Persists
File locking (fcntl): ✅ Working
flock command: ✅ Working
Network access: ✅ Can access network
Python packages: ✅ All required packages installed
Environment vars: ✅ Can read USER, HOME

=== Sandbox Compatibility Summary ===

Test Results:
  ✅ Passed: 10
  ❌ Failed: 0
  ⚠️  Warnings: 0

✅ FULL COMPATIBILITY
   All features will work in this environment

Graceful Degradation Strategy:
  If CLAUDE_SANDBOX_MODE is set, hooks should:
  1. Detect sandbox environment
  2. Skip background worker operations
  3. Exit cleanly without errors
  4. Log warning to user about limited functionality
```

---

## Running All Tests

To run all tests sequentially:

```bash
cd /Volumes/code/personal/github/amplicode/plugin/tests

# Run all tests
for test in test_*.sh; do
    echo "========================================"
    echo "Running $test"
    echo "========================================"
    ./"$test"
    echo ""
done
```

Or use the master test runner:

```bash
./run_all_tests.sh
```

---

## Test Priority

### Critical (Must Pass Before Release)
1. **test_hook_performance.sh** - Performance is essential
2. **test_multi_session.sh** - Data safety is non-negotiable

### Important (Should Pass)
3. **test_macos_setup.sh** - Environment validation
4. **test_sandbox.sh** - Compatibility awareness

---

## Continuous Integration

These tests should be run:
- Before every commit to main
- On pull requests
- After any hook modifications
- After worker modifications
- On different macOS versions

---

## Test Output

All tests:
- Exit with code 0 on success
- Exit with code 1 on failure
- Use colored output (green ✅, red ❌, yellow ⚠️)
- Provide detailed failure messages
- Are independent (can run in any order)
- Clean up after themselves

---

## Adding New Tests

When adding new tests:
1. Follow naming convention: `test_<feature>.sh`
2. Make executable: `chmod +x test_<feature>.sh`
3. Include clear output with ✅/❌/⚠️
4. Exit 0 on success, 1 on failure
5. Clean up temporary files
6. Add documentation to this README

---

## Troubleshooting

### "Permission denied" errors
```bash
chmod +x test_*.sh
```

### "flock: command not found"
```bash
brew install util-linux
```

### "Python module not found"
```bash
pip3 install anthropic psutil
```

### Tests fail on CI/CD
- Check Python version (need 3.11+)
- Check file permissions
- Check flock availability
- Check network access (for API tests)

---

## License

Part of the Amplicode project.
