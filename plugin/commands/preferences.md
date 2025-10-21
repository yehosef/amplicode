# Amplicode Preferences

View learned preferences organized by scope (Global → Language → Project).

```bash
#!/bin/bash
set -euo pipefail

# File paths
GLOBAL_MEMORY="${HOME}/.claude/global_memory.json"
CONTEXT_MEMORY="${HOME}/.claude/context_memory.json"
PROJECT_MEMORY="${PWD}/.data/memory.json"

# Parse arguments
PREFERENCE_ID=""
SHOW_ALL=false

for arg in "$@"; do
    case $arg in
        --id=*)
            PREFERENCE_ID="${arg#*=}"
            ;;
        --all)
            SHOW_ALL=true
            ;;
    esac
done

echo "📚 Amplicode Learned Preferences"
echo ""

# Check if any memory files exist
HAS_ANY=false
[ -f "$GLOBAL_MEMORY" ] && HAS_ANY=true
[ -f "$CONTEXT_MEMORY" ] && HAS_ANY=true
[ -f "$PROJECT_MEMORY" ] && HAS_ANY=true

if [ "$HAS_ANY" = false ]; then
    echo "📭 No preferences learned yet"
    echo ""
    echo "   Amplicode learns from your corrections and patterns."
    echo "   As you work, preferences will be saved here."
    echo ""
    echo "💡 To explicitly teach a preference:"
    echo "   /amplicode-learn \"Always use file-based state over Redis\""
    exit 0
fi

# Function to display preferences from a file
display_preferences() {
    local file=$1
    local scope=$2
    local emoji=$3

    if [ ! -f "$file" ]; then
        return 0
    fi

    python3 <<EOF
import json
from datetime import datetime

try:
    with open("$file") as f:
        data = json.load(f)

    prefs = data.get("preferences", [])

    if not prefs:
        return

    print("$emoji $scope")
    print("")

    # Filter by ID if specified
    if "$PREFERENCE_ID":
        prefs = [p for p in prefs if p.get("id") == "$PREFERENCE_ID"]

    # Show limited number unless --all
    if not $SHOW_ALL and len(prefs) > 5:
        prefs = prefs[:5]
        show_more = True
    else:
        show_more = False

    for i, pref in enumerate(prefs, 1):
        pref_id = pref.get("id", "unknown")
        description = pref.get("description", "No description")
        confidence = pref.get("confidence", 0.0)
        learned_at = pref.get("learned_at", 0)
        applied_count = pref.get("applied_count", 0)

        # Format timestamp
        if learned_at:
            learned_date = datetime.fromtimestamp(learned_at).strftime("%Y-%m-%d")
        else:
            learned_date = "unknown"

        # Format confidence with color
        conf_str = f"{confidence:.0%}"
        if confidence >= 0.8:
            conf_emoji = "🟢"
        elif confidence >= 0.5:
            conf_emoji = "🟡"
        else:
            conf_emoji = "🔴"

        print(f"   {i}. {description}")
        print(f"      ID: {pref_id}")
        print(f"      Confidence: {conf_emoji} {conf_str}")
        print(f"      Learned: {learned_date}")
        print(f"      Applied: {applied_count} times")

        # Show pattern if available
        pattern = pref.get("pattern", {})
        if pattern:
            print(f"      Pattern: {pattern.get('type', 'unknown')}")

        print("")

    if show_more:
        print(f"   ... and {len(data.get('preferences', [])) - 5} more")
        print(f"   💡 Show all with: /amplicode-preferences --all")
        print("")

except FileNotFoundError:
    pass
except json.JSONDecodeError as e:
    print(f"   ⚠️  Error reading preferences: {e}")
    print("")
except Exception as e:
    print(f"   ❌ Error: {e}")
    print("")

EOF
}

# Display preferences by scope (highest precedence last)
if [ -f "$GLOBAL_MEMORY" ]; then
    display_preferences "$GLOBAL_MEMORY" "Global Preferences" "🌍"
fi

if [ -f "$CONTEXT_MEMORY" ]; then
    display_preferences "$CONTEXT_MEMORY" "Language/Context Preferences" "🔧"
fi

if [ -f "$PROJECT_MEMORY" ]; then
    display_preferences "$PROJECT_MEMORY" "Project Preferences" "📁"
    echo "────────────────────────────────────────────────────────────────"
    echo ""
fi

# Summary
echo "💡 Preference Hierarchy:"
echo "   1. Project preferences (highest priority) - apply to this project only"
echo "   2. Language preferences (medium priority) - apply to similar contexts"
echo "   3. Global preferences (lowest priority) - apply everywhere"
echo ""
echo "   When conflicts occur, project preferences win."
echo ""

# Show file locations
echo "📂 Files:"
[ -f "$GLOBAL_MEMORY" ] && echo "   Global: $GLOBAL_MEMORY"
[ -f "$CONTEXT_MEMORY" ] && echo "   Language: $CONTEXT_MEMORY"
[ -f "$PROJECT_MEMORY" ] && echo "   Project: $PROJECT_MEMORY"
echo ""

# Show options
echo "🛠️  Management:"
echo "   View specific: /amplicode-preferences --id=<preference-id>"
echo "   View all: /amplicode-preferences --all"
echo "   Edit: /amplicode-edit-preference --id=<preference-id>"
echo "   Teach new: /amplicode-learn \"<your preference>\""
```
