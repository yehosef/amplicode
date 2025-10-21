# Save Learned Preferences

Saves the preferences you just extracted to the project's memory file.

**Usage:** After running `/amplicode-process` and creating the JSON structure,
provide the JSON and run this command to save it.

```bash
#!/bin/bash
set -euo pipefail

PROJECT_ROOT="${PWD}"
MEMORY_FILE="${PROJECT_ROOT}/.data/memory.json"

echo "📝 Paste the JSON preferences structure you created:"
echo "(Or provide as argument)"
echo ""

# This will be replaced by actual JSON from user or previous command
```

```python
import json
import sys
import fcntl
from pathlib import Path
from datetime import datetime

# In real usage, this would receive JSON from the user or stdin
# For now, show instructions

print("**To save preferences:**")
print("")
print("1. Create a JSON structure with your extracted preferences")
print("2. Use the Write tool to write it to `.data/memory.json`")
print("")
print("**Example:**")
print("")
print("```python")
print("# Use Write tool")
print('Write(".data/memory.json", """')
print("{")
print('  "preferences": [')
print("    {")
print('      "type": "prefer",')
print('      "subject": "local files over Redis",')
print('      "context": "This legacy monolith",')
print('      "scope": "project",')
print('      "raw_text": "No, use local files instead of Redis",')
print('      "confidence": 0.95,')
print('      "learned_at": "' + datetime.now().isoformat() + '"')
print("    }")
print("  ],")
print('  "version": "1.0",')
print('  "updated_at": "' + datetime.now().isoformat() + '"')
print("}")
print('""")')
print("```")
print("")
print("✅ The preferences will be loaded on your next session")
```
