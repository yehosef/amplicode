#!/bin/bash
# test_multi_session.sh - Verify data safety with multiple concurrent sessions
# Simulates 3 concurrent Claude Code sessions writing to the queue
# Critical test: Ensures file locking prevents data corruption

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if colors are supported
if [ ! -t 1 ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

echo "=== Multi-Session Data Safety Test ==="
echo "Simulating 3 concurrent sessions writing to queue..."
echo ""

# Setup test environment
TEST_DIR="/tmp/amplicode_test_$$"
TEST_QUEUE="$TEST_DIR/learning_queue.jsonl"
LOCK_FILE="/tmp/claude_learning_queue_test_$$.lock"

mkdir -p "$TEST_DIR"

# Cleanup function
cleanup() {
    rm -rf "$TEST_DIR"
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT

# Function to simulate a session writing events
simulate_session() {
    local session_id="$1"
    local num_events="$2"
    local project_path="/test/project/$session_id"

    for i in $(seq 1 $num_events); do
        local timestamp=$(date +%s)

        # Generate JSON event
        if command -v jq &> /dev/null; then
            EVENT_JSON=$(jq -n \
                --arg project "$project_path" \
                --arg session "$session_id" \
                --arg timestamp "$timestamp" \
                --arg seq "$i" \
                '{
                    project: $project,
                    session: $session,
                    event_type: "stop",
                    timestamp: ($timestamp | tonumber),
                    sequence: ($seq | tonumber)
                }')
        else
            # Fallback to Python
            EVENT_JSON=$(python3 -c "
import json
print(json.dumps({
    'project': '$project_path',
    'session': '$session_id',
    'event_type': 'stop',
    'timestamp': $timestamp,
    'sequence': $i
}, separators=(',', ':')))
")
        fi

        # Atomic append with file lock (same pattern as hooks)
        {
            flock -x 200
            echo "$EVENT_JSON" >> "$TEST_QUEUE"
        } 200>"$LOCK_FILE"

        # Small random delay to increase chance of contention
        sleep 0.0$((RANDOM % 5))
    done
}

# Test configuration
NUM_SESSIONS=3
EVENTS_PER_SESSION=20
EXPECTED_TOTAL=$((NUM_SESSIONS * EVENTS_PER_SESSION))

echo "Configuration:"
echo "  Sessions: $NUM_SESSIONS"
echo "  Events per session: $EVENTS_PER_SESSION"
echo "  Expected total events: $EXPECTED_TOTAL"
echo ""

# Run sessions in parallel
echo "Starting concurrent sessions..."
for session in $(seq 1 $NUM_SESSIONS); do
    simulate_session "session$session" $EVENTS_PER_SESSION &
done

# Wait for all sessions to complete
wait

echo -e "${GREEN}✅ All sessions completed${NC}"
echo ""

# Verify results
echo "=== Verification ==="

# Test 1: File exists
echo -n "Queue file exists: "
if [ -f "$TEST_QUEUE" ]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌ Queue file not created${NC}"
    exit 1
fi

# Test 2: Correct number of events
echo -n "Event count: "
ACTUAL_COUNT=$(wc -l < "$TEST_QUEUE" | tr -d ' ')
if [ "$ACTUAL_COUNT" -eq "$EXPECTED_TOTAL" ]; then
    echo -e "${GREEN}✅ $ACTUAL_COUNT events (expected $EXPECTED_TOTAL)${NC}"
else
    echo -e "${RED}❌ $ACTUAL_COUNT events (expected $EXPECTED_TOTAL)${NC}"
    echo "   Missing or duplicate events detected"
    exit 1
fi

# Test 3: All events are valid JSON
echo -n "JSON validity: "
INVALID_LINES=0
while IFS= read -r line; do
    if ! echo "$line" | python3 -c "import sys, json; json.loads(sys.stdin.read())" 2>/dev/null; then
        INVALID_LINES=$((INVALID_LINES + 1))
    fi
done < "$TEST_QUEUE"

if [ $INVALID_LINES -eq 0 ]; then
    echo -e "${GREEN}✅ All events are valid JSON${NC}"
else
    echo -e "${RED}❌ $INVALID_LINES invalid JSON lines${NC}"
    echo "   Data corruption detected"
    exit 1
fi

# Test 4: No duplicate events
echo -n "Duplicate check: "
DUPLICATES=$(sort "$TEST_QUEUE" | uniq -d | wc -l | tr -d ' ')
if [ "$DUPLICATES" -eq 0 ]; then
    echo -e "${GREEN}✅ No duplicate events${NC}"
else
    echo -e "${RED}❌ $DUPLICATES duplicate events found${NC}"
    exit 1
fi

# Test 5: Verify all sessions wrote their events
echo -n "Session completeness: "
ALL_SESSIONS_COMPLETE=true
for session in $(seq 1 $NUM_SESSIONS); do
    SESSION_COUNT=$(grep -c "\"session\":\"session$session\"" "$TEST_QUEUE" || echo "0")
    if [ "$SESSION_COUNT" -ne "$EVENTS_PER_SESSION" ]; then
        echo -e "${RED}❌ Session $session: $SESSION_COUNT events (expected $EVENTS_PER_SESSION)${NC}"
        ALL_SESSIONS_COMPLETE=false
    fi
done

if [ "$ALL_SESSIONS_COMPLETE" = true ]; then
    echo -e "${GREEN}✅ All sessions wrote expected events${NC}"
else
    exit 1
fi

# Test 6: Verify sequence numbers are correct
echo -n "Sequence integrity: "
SEQUENCE_ERRORS=0
for session in $(seq 1 $NUM_SESSIONS); do
    # Extract sequences for this session and verify 1..N
    SEQUENCES=$(grep "\"session\":\"session$session\"" "$TEST_QUEUE" | \
                python3 -c "
import sys, json
sequences = []
for line in sys.stdin:
    data = json.loads(line)
    sequences.append(data['sequence'])
sequences.sort()
expected = list(range(1, len(sequences) + 1))
if sequences != expected:
    print('ERROR')
else:
    print('OK')
" 2>/dev/null || echo "ERROR")

    if [ "$SEQUENCES" = "ERROR" ]; then
        SEQUENCE_ERRORS=$((SEQUENCE_ERRORS + 1))
    fi
done

if [ $SEQUENCE_ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All sequences intact${NC}"
else
    echo -e "${RED}❌ $SEQUENCE_ERRORS sessions have sequence errors${NC}"
    exit 1
fi

echo ""
echo "=== File Locking Test ==="

# Test 7: Verify file locking works (simulate contention)
echo "Testing concurrent lock acquisition..."

LOCK_TEST_FILE="/tmp/lock_test_$$.txt"
LOCK_TEST_LOCK="/tmp/lock_test_$$.lock"

# Function to test locking
test_lock() {
    local id="$1"
    for i in {1..10}; do
        {
            flock -x 200
            echo "$id:$i" >> "$LOCK_TEST_FILE"
            sleep 0.01  # Hold lock briefly
        } 200>"$LOCK_TEST_LOCK"
    done
}

# Run concurrent lock tests
for i in {1..3}; do
    test_lock "proc$i" &
done
wait

# Verify all writes succeeded
LOCK_TEST_COUNT=$(wc -l < "$LOCK_TEST_FILE" | tr -d ' ')
if [ "$LOCK_TEST_COUNT" -eq 30 ]; then
    echo -e "${GREEN}✅ File locking working correctly (30/30 writes)${NC}"
else
    echo -e "${RED}❌ Lock contention issues ($LOCK_TEST_COUNT/30 writes)${NC}"
    rm -f "$LOCK_TEST_FILE" "$LOCK_TEST_LOCK"
    exit 1
fi

rm -f "$LOCK_TEST_FILE" "$LOCK_TEST_LOCK"

echo ""
echo "=== Multi-Session Test Summary ==="
echo -e "${GREEN}✅ All data safety tests passed${NC}"
echo ""
echo "Results:"
echo "  - No data corruption"
echo "  - No missing events"
echo "  - No duplicate events"
echo "  - File locking prevents race conditions"
echo "  - Safe for concurrent Claude Code sessions"

exit 0
