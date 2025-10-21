# Amplicode Plugin Test Suite - Summary

## Overview

Four comprehensive test scripts have been created to validate the Amplicode plugin:

1. **test_hook_performance.sh** - Performance validation
2. **test_macos_setup.sh** - Environment prerequisites
3. **test_multi_session.sh** - Data safety with concurrent sessions
4. **test_sandbox.sh** - Sandbox mode compatibility

Plus:
- **run_all_tests.sh** - Master test runner
- **README.md** - Comprehensive documentation

---

## Test Scripts Details

### 1. test_hook_performance.sh (2.8 KB)
**Purpose:** Ensure hooks execute in <50ms

**Methodology:**
- Runs each hook 10 times
- Measures execution time with Python time.time()
- Reports average, min, max
- FAILS if average >50ms

**Tests:**
- stop_hook.sh (fires 50-100x per session)
- sessionend_hook.sh (fires 1x per session)
- sessionstart_hook.sh (fires 1x per session)

**Critical Because:**
- Hook latency directly impacts Claude Code responsiveness
- 50-100 calls per session means slow hooks = slow experience
- Bash hooks should be 15-30x faster than Python (10-20ms vs 250-350ms)

---

### 2. test_macos_setup.sh (5.0 KB)
**Purpose:** Verify all prerequisites are met

**Checks:**
- ✅ Python 3.11+ installed
- ✅ jq installed (optional but recommended)
- ✅ anthropic package installed
- ✅ psutil package installed
- ✅ File locking works (fcntl)
- ✅ ~/.claude/ directory exists and writable
- ✅ /tmp/ access for lock files
- ✅ Process spawning works
- ✅ Date command works
- ✅ Bash version
- ✅ flock command available

**Output:**
- Clear ✅/❌/⚠️ for each check
- Installation commands for missing dependencies
- Overall pass/fail status

---

### 3. test_multi_session.sh (6.8 KB)
**Purpose:** Verify data safety with concurrent sessions

**Test Scenario:**
- Simulates 3 concurrent Claude Code sessions
- Each writes 20 events to shared queue
- Total: 60 events expected

**Validations:**
- All 60 events written (no missing)
- No duplicate events
- All events are valid JSON (no corruption)
- Each session wrote exactly 20 events
- Sequence numbers intact for each session
- File locking prevents race conditions

**Critical Because:**
- Users often have multiple Claude Code windows
- Without file locking, concurrent writes corrupt JSONL
- Data corruption is unacceptable

**Additional Tests:**
- Concurrent lock acquisition test
- Verifies flock prevents simultaneous writes

---

### 4. test_sandbox.sh (7.4 KB)
**Purpose:** Determine what works in sandbox mode

**Tests 10 Capabilities:**
1. Write to .data/ (local project memory)
2. Write to ~/.claude/ (global queue)
3. Write to /tmp/ (lock files)
4. Spawn subprocess (worker)
5. Background persistence (worker survives hook exit)
6. File locking with fcntl
7. File locking with flock
8. Network access (Anthropic API)
9. Python packages (anthropic, psutil)
10. Environment variables (USER, HOME)

**Output:**
- ✅ Passed / ❌ Failed / ⚠️ Warning for each
- Impact description for failures
- Overall compatibility level:
  - FULL COMPATIBILITY (all pass)
  - PARTIAL COMPATIBILITY (some warnings)
  - LIMITED COMPATIBILITY (critical failures)

**Graceful Degradation Strategy:**
- If CLAUDE_SANDBOX_MODE detected, exit cleanly
- Log warning to user
- Don't block Claude Code

---

## Master Test Runner (3.1 KB)

**run_all_tests.sh:**
- Runs all tests sequentially
- Tracks pass/fail/skip
- Color-coded output
- Summary report
- Exit code 0 if all pass, 1 if any fail

**Usage:**
```bash
cd /Volumes/code/personal/github/amplicode/plugin/tests
./run_all_tests.sh
```

---

## Test Priority

### 🚨 CRITICAL (Must Pass Before Release)
1. **test_hook_performance.sh** - Performance directly impacts UX
2. **test_multi_session.sh** - Data corruption is unacceptable

### ⚠️ IMPORTANT (Should Pass)
3. **test_macos_setup.sh** - Validates environment
4. **test_sandbox.sh** - Enables graceful degradation

---

## Running Tests

### Individual Tests
```bash
cd /Volumes/code/personal/github/amplicode/plugin/tests

# Performance test
./test_hook_performance.sh

# Setup check
./test_macos_setup.sh

# Data safety test
./test_multi_session.sh

# Sandbox compatibility
./test_sandbox.sh

# Test sandbox mode explicitly
CLAUDE_SANDBOX_MODE=1 ./test_sandbox.sh
```

### All Tests
```bash
# Run all tests with summary
./run_all_tests.sh
```

---

## Expected Results (Normal Environment)

### test_macos_setup.sh
```
Python 3.11+: ✅
jq: ✅
anthropic: ✅
psutil: ✅
File locking: ✅
~/.claude/: ✅
All prerequisites met
```

### test_hook_performance.sh
```
stop_hook.sh: Average 15ms ✅
sessionend_hook.sh: Average 18ms ✅
sessionstart_hook.sh: Average 45ms ✅
All hooks <50ms ✅
```

### test_multi_session.sh
```
60/60 events written ✅
No corruption ✅
No duplicates ✅
File locking works ✅
```

### test_sandbox.sh
```
10/10 capabilities work ✅
FULL COMPATIBILITY ✅
```

---

## Common Issues & Fixes

### flock not found
```bash
brew install util-linux
```

### Python packages missing
```bash
pip3 install anthropic psutil
```

### Permission denied on tests
```bash
chmod +x test_*.sh run_all_tests.sh
```

### /tmp/ write failures
- May be running in sandbox mode
- Check CLAUDE_SANDBOX_MODE environment variable
- Expected in sandboxed environments

### Hooks failing in performance test
- Check if flock is installed
- Check if ~/.claude/ is writable
- Check if /tmp/ is writable
- May need to run outside sandbox

---

## CI/CD Integration

These tests should be automated:

```bash
# In CI pipeline
cd plugin/tests
./run_all_tests.sh || exit 1
```

**Run on:**
- Every commit to main
- Pull requests
- Pre-release
- After dependency updates

---

## Test Maintenance

### When to Update Tests

**test_hook_performance.sh:**
- When adding new hooks
- When changing hook implementation
- When performance target changes

**test_macos_setup.sh:**
- When adding new dependencies
- When minimum versions change
- When supporting new platforms

**test_multi_session.sh:**
- When changing queue format
- When modifying file locking strategy
- When adding new concurrency scenarios

**test_sandbox.sh:**
- When adding features that need specific permissions
- When sandbox mode restrictions change
- When graceful degradation changes

---

## File Locations

All test files are in:
```
/Volumes/code/personal/github/amplicode/plugin/tests/
├── README.md                    # Comprehensive documentation
├── TEST_SUMMARY.md              # This file
├── run_all_tests.sh             # Master test runner
├── test_hook_performance.sh     # Performance validation
├── test_macos_setup.sh          # Prerequisites check
├── test_multi_session.sh        # Data safety test
└── test_sandbox.sh              # Sandbox compatibility
```

All scripts are executable (chmod +x).

---

## Success Criteria

### Week 1 Success
- ✅ All test scripts created
- ✅ All scripts executable
- ✅ Clear pass/fail output
- ✅ Comprehensive documentation

### Before Release
- ✅ test_hook_performance.sh passes (all hooks <50ms)
- ✅ test_multi_session.sh passes (no data corruption)
- ⚠️ test_macos_setup.sh passes or provides clear fix instructions
- ℹ️ test_sandbox.sh documents compatibility level

---

## Summary

Four robust test scripts have been created that validate:
1. **Performance** - Hooks execute fast enough (<50ms)
2. **Prerequisites** - Environment has all dependencies
3. **Data Safety** - Concurrent sessions don't corrupt data
4. **Compatibility** - Graceful degradation in sandbox mode

These tests are **critical** for ensuring the Amplicode plugin:
- Doesn't slow down Claude Code
- Doesn't lose or corrupt user data
- Works in varied environments
- Degrades gracefully when limited

**Next Steps:**
1. Run tests in target environment
2. Fix any failures
3. Integrate into CI/CD
4. Run before every release
