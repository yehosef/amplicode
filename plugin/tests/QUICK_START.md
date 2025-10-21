# Amplicode Tests - Quick Start Guide

## TL;DR - Run All Tests

```bash
cd /Volumes/code/personal/github/amplicode/plugin/tests
./run_all_tests.sh
```

---

## Individual Tests

### 1. Check Prerequisites (Run First!)
```bash
./test_macos_setup.sh
```

**What it checks:** Python 3.11+, jq, anthropic, psutil, flock, file permissions

**If it fails:**
```bash
brew install python@3.11 jq util-linux
pip3 install anthropic psutil
chmod 700 ~/.claude
```

---

### 2. Test Hook Performance (Critical!)
```bash
./test_hook_performance.sh
```

**Pass criteria:** All hooks average <50ms

**Why it matters:** Slow hooks = slow Claude Code

---

### 3. Test Data Safety (Critical!)
```bash
./test_multi_session.sh
```

**What it tests:** 3 concurrent sessions writing to queue

**Pass criteria:**
- All events written
- No corruption
- No duplicates
- File locking works

---

### 4. Test Sandbox Compatibility
```bash
./test_sandbox.sh

# Or test sandbox mode explicitly
CLAUDE_SANDBOX_MODE=1 ./test_sandbox.sh
```

**What it reports:** Which features work/don't work in sandbox

---

## Before Committing

```bash
# Quick check
./test_hook_performance.sh && ./test_multi_session.sh
```

---

## Before Release

```bash
# Full suite
./run_all_tests.sh
```

Must pass:
- ✅ test_hook_performance.sh
- ✅ test_multi_session.sh

Should pass:
- ✅ test_macos_setup.sh (or provide fixes)

---

## Interpreting Results

### ✅ Green = Pass
Everything working as expected

### ❌ Red = Fail
Critical issue, must fix before release

### ⚠️ Yellow = Warning
Non-critical, but should investigate

---

## Common Fixes

### Missing flock
```bash
brew install util-linux
```

### Missing Python packages
```bash
pip3 install anthropic psutil
```

### Permission errors
```bash
chmod +x *.sh
chmod 700 ~/.claude
```

---

## Documentation

- **README.md** - Full test documentation
- **TEST_SUMMARY.md** - Detailed test descriptions
- **QUICK_START.md** - This file

---

## Help

If tests fail unexpectedly:
1. Check prerequisites with `./test_macos_setup.sh`
2. Review error messages (tests are verbose)
3. Check sandbox mode with `./test_sandbox.sh`
4. Review test documentation in README.md
