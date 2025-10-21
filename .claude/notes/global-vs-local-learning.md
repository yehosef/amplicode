# Global vs Local Learning Strategy

**Date:** 2025-10-22
**Status:** Architecture Decision Document
**Context:** Determining when preferences should be learned globally vs project-specifically

---

## The Core Problem

**User Scenario:**
> "In one project I may not prefer Redis because it's not the right tool in that case - but somewhere else I would. Certain learning might be language or platform dependent."

**The Challenge:** Not all preferences are universal. Some are:
- **Contextual** - "Use Redis for this microservices project, files for this monolith"
- **Language-specific** - "Use pytest in Python projects, vitest in TypeScript projects"
- **Platform-specific** - "Use Docker on Linux servers, native on macOS development"
- **Team-specific** - "This team prefers functional style, that team prefers OOP"

**What we need:** A system that learns **when** a preference applies, not just **what** the preference is.

---

## Research: How Others Solve This

### GitHub Copilot (3-Level Hierarchy)

**Precedence:** Repository > Organization > User

```
User Level:           "I prefer descriptive variable names"
↓ (overridden by)
Organization Level:   "Use company's auth library"
↓ (overridden by)
Repository Level:     "This legacy project uses short names for historical reasons"
```

**Implementation:**
- User: Personal settings in account
- Organization: `.github/organization-instructions.md`
- Repository: `.github/copilot-instructions.md`

**Key Insight:** More specific context overrides more general context.

### Cursor (2-Level Hierarchy)

**Precedence:** Project Rules > User Rules

```
User Rules (Global):     "Use TypeScript for all projects"
↓ (overridden by)
Project Rules:           ".cursor/rules - This project is Python-only"
```

**Implementation:**
- User: Global settings in Cursor Settings → Rules
- Project: `.cursor/rules` directory (version-controlled)

**Key Insight:** Project-specific knowledge encoded in version control.

### EditorConfig (Override Pattern)

**Precedence:** Local > Parent > Root

```
~/                      (root)    indent_size = 4
~/projects/             (parent)  indent_size = 2
~/projects/legacy/      (local)   indent_size = 8  ← wins
```

**Key Insight:** Closest context to the file wins.

### Academic Research (Hierarchical Learning)

**Group-in-Group Policy Optimization (2024):**
- **Global trajectory quality** - Did the agent complete the entire task successfully?
- **Local step effectiveness** - Was this specific action helpful?

**Multi-Agent Memory Systems (2025):**
- **Short-term memory** - Context within current task
- **Long-term memory** - Historical preferences and patterns

**Context-Aware Personalization Frameworks:**
- **Persona** - Recognition of user and their behavior
- **Context** - Awareness of current situation
- **Intent** - Comprehension and projection of future needs

**Key Insight:** Effective systems capture preferences at multiple levels and apply them hierarchically.

---

## Amplicode Strategy: 3-Level Hierarchy

### Level 1: Global User Preferences (Strongest)

**Location:** `~/.claude/global_memory.json`

**What to learn:**
- ✅ **Universal style preferences** - "Always use descriptive variable names"
- ✅ **Language-agnostic patterns** - "Prefer composition over inheritance"
- ✅ **Communication style** - "Be concise, no pleasantries"
- ✅ **Absolute rejections** - "Never use eval() in any language"
- ✅ **Tool preferences when unconstrained** - "Default to pytest when no test framework exists"

**Examples:**
```json
{
  "preferences": [
    {
      "type": "communication_style",
      "preference": "concise_technical",
      "learned_from": "User repeatedly says 'just show me the code'",
      "confidence": 0.95,
      "applies_to": "all_projects"
    },
    {
      "type": "code_style",
      "preference": "descriptive_names",
      "learned_from": "User corrects abbreviated names to full words",
      "confidence": 0.90,
      "applies_to": "all_projects"
    }
  ]
}
```

**When to use:** Always active, unless overridden by project or language context.

### Level 2: Language/Platform Context (Medium)

**Location:** `~/.claude/context_memory.json`

**What to learn:**
- ✅ **Language-specific preferences** - "Use pytest in Python, vitest in JS"
- ✅ **Platform-specific patterns** - "Use systemd on Linux, launchd on macOS"
- ✅ **Stack preferences** - "For web projects: React + Tailwind"
- ✅ **Framework choices** - "For Python CLI tools: Click library"

**Examples:**
```json
{
  "contexts": {
    "python": {
      "test_framework": {
        "preference": "pytest",
        "confidence": 0.85,
        "learned_from": "User chose pytest in 5 different Python projects"
      },
      "async_library": {
        "preference": "asyncio",
        "not": "twisted",
        "confidence": 0.90,
        "learned_from": "User rejected Twisted, specified asyncio"
      }
    },
    "javascript": {
      "test_framework": {
        "preference": "vitest",
        "confidence": 0.80,
        "learned_from": "User selected vitest over jest in 3 projects"
      }
    },
    "platform:macos": {
      "process_manager": {
        "preference": "launchd",
        "confidence": 1.0,
        "learned_from": "System requirement"
      }
    }
  }
}
```

**When to use:** When language/platform is detected, apply these preferences unless project overrides.

### Level 3: Project-Specific Preferences (Weakest Override, Strongest Context)

**Location:** `<project>/.data/memory.json`

**What to learn:**
- ✅ **Project constraints** - "This legacy project uses files, not Redis"
- ✅ **Team conventions** - "This team uses OOP style, not functional"
- ✅ **Architecture decisions** - "This project uses microservices pattern"
- ✅ **Existing tech stack** - "This project already has Express, don't suggest Fastify"
- ✅ **Project-specific rejections** - "Don't refactor the legacy auth module"

**Examples:**
```json
{
  "project": "/Users/yehosef/projects/legacy-monolith",
  "preferences": [
    {
      "type": "data_storage",
      "preference": "local_files",
      "not": "redis",
      "reason": "Simple monolith, no need for Redis complexity",
      "confidence": 0.95,
      "learned_from": "User: 'No Redis, use files instead' (Session 23)"
    },
    {
      "type": "architecture",
      "preference": "monolith_pattern",
      "confidence": 0.90,
      "learned_from": "Codebase analysis + user corrections"
    }
  ]
}
```

**When to use:** Only when working in this specific project directory.

---

## Precedence Rules (Conflict Resolution)

**When preferences conflict, apply in this order:**

```
1. Project-Specific      (Highest precedence)
   ↓
2. Language/Platform     (Medium precedence)
   ↓
3. Global User          (Lowest precedence, always active)
```

### Example Conflict Resolution

**Scenario:** User is in a Python project that uses unittest (legacy)

**Global Preference:**
```json
{"test_framework": "pytest", "confidence": 0.85}
```

**Language Context (Python):**
```json
{"test_framework": "pytest", "confidence": 0.90}
```

**Project Preference:**
```json
{"test_framework": "unittest", "reason": "Legacy codebase", "confidence": 0.95}
```

**Result:** Use `unittest` (project-specific wins)

**Claude's behavior:**
- Suggests unittest for tests
- Doesn't suggest migrating to pytest (respects project context)
- In a NEW Python project without this override → suggests pytest

---

## Context Detection Strategy

### How to Determine Context

**Language Detection:**
```python
def detect_language_context(project_path):
    # Look for indicators
    indicators = {
        'python': ['*.py', 'requirements.txt', 'pyproject.toml'],
        'javascript': ['*.js', 'package.json'],
        'rust': ['Cargo.toml'],
        # etc.
    }
    # Return primary language(s)
```

**Platform Detection:**
```python
def detect_platform_context():
    return {
        'os': platform.system(),  # macOS, Linux, Windows
        'arch': platform.machine(),  # arm64, x86_64
    }
```

**Project Type Detection:**
```python
def detect_project_type(project_path):
    # Heuristics:
    # - Multiple services in subdirs → microservices
    # - Single main.py/app.py → monolith
    # - package.json with "type": "module" → ESM project
    # - Docker compose → containerized
    # - etc.
```

**Confidence Scoring:**
```python
def apply_preferences(global_prefs, context_prefs, project_prefs):
    # Merge with precedence
    merged = {}

    # Start with global (lowest precedence)
    for pref in global_prefs:
        merged[pref.key] = pref

    # Override with context
    for pref in context_prefs:
        if pref.key in merged and pref.confidence > 0.7:
            merged[pref.key] = pref

    # Override with project (highest precedence)
    for pref in project_prefs:
        merged[pref.key] = pref

    return merged
```

---

## Learning Signals for Each Level

### Global Learning (User-Wide)

**What triggers global learning:**
- User corrects same thing across **3+ different projects**
- User states explicit preference: "I always prefer X"
- User rejects something repeatedly in different contexts

**Extraction prompt:**
```
Given these 3 corrections across different projects:
- Project A (Python microservice): User rejected Redis → files
- Project B (Node.js API): User rejected Redis → files
- Project C (Ruby script): User rejected Redis → files

Is this a GLOBAL preference or CONTEXT-SPECIFIC?
→ GLOBAL: User prefers file-based storage over Redis generally
   (Confidence: 0.90 due to cross-language/cross-project pattern)
```

### Language/Platform Learning

**What triggers language context learning:**
- User corrects same thing across **2+ projects in same language**
- User states language-specific preference: "For Python, use pytest"

**Extraction prompt:**
```
Given these 2 corrections in Python projects:
- Project A (Python CLI): User chose pytest over unittest
- Project B (Python web): User chose pytest over unittest

Is this LANGUAGE-SPECIFIC or PROJECT-SPECIFIC?
→ LANGUAGE-SPECIFIC: In Python projects, user prefers pytest
   (Confidence: 0.85, applies to all Python projects)
```

### Project Learning

**What triggers project-specific learning:**
- User corrects something **within current project**
- User provides project-specific context: "This legacy project uses X"
- User rejects suggestion that conflicts with existing project code

**Extraction prompt:**
```
User correction in /projects/legacy-monolith:
User: "No Redis, this is a simple monolith, use local files"

Context: Existing codebase has no Redis dependencies
Is this PROJECT-SPECIFIC or GLOBAL?
→ PROJECT-SPECIFIC: User chose files over Redis due to project simplicity
   (Confidence: 0.95, applies only to this project)
```

---

## Implementation Strategy

### Phase 1: Single-Level (Project-Only)

**Simplest start:** Learn preferences per-project only
- Location: `<project>/.data/memory.json`
- No global preferences yet
- Validates the correction pattern works

**Pros:**
- Simple to implement
- No conflict resolution needed
- Validates core learning loop

**Cons:**
- User repeats corrections across projects
- Can't share language preferences

### Phase 2: Add Global Level

**Add:** `~/.claude/global_memory.json`
- Learn preferences that apply everywhere
- Project preferences override global

**Migration:**
```python
def promote_to_global(project_prefs):
    # If same preference exists in 3+ projects, promote to global
    cross_project_count = count_preference_across_projects(pref)
    if cross_project_count >= 3:
        promote_to_global(pref)
        remove_from_projects(pref)  # Deduplicate
```

### Phase 3: Add Language/Platform Context

**Add:** `~/.claude/context_memory.json`
- Learn language-specific preferences
- Platform-specific preferences
- 3-level hierarchy complete

**Complexity:**
- Must detect language/platform on SessionStart
- Must resolve 3-way conflicts
- Most flexible system

---

## Data Structure Design

### Global Memory
```json
{
  "version": "1.0",
  "user_id": "yehosef",
  "preferences": [
    {
      "id": "pref_001",
      "type": "communication_style",
      "preference": "concise_technical",
      "confidence": 0.95,
      "learned_from": [
        {"project": "amplicode", "session": 5, "correction": "Just show code"},
        {"project": "other-proj", "session": 2, "correction": "Skip explanation"}
      ],
      "applies_to": "all_projects",
      "created_at": "2025-10-22T10:00:00Z",
      "last_reinforced": "2025-10-23T14:30:00Z"
    }
  ]
}
```

### Context Memory
```json
{
  "version": "1.0",
  "contexts": {
    "python": {
      "preferences": [
        {
          "id": "ctx_py_001",
          "type": "test_framework",
          "preference": "pytest",
          "confidence": 0.85,
          "learned_from": [
            {"project": "proj-a", "session": 3},
            {"project": "proj-b", "session": 7}
          ],
          "created_at": "2025-10-20T10:00:00Z"
        }
      ]
    },
    "platform:macos": {
      "preferences": [
        {
          "id": "ctx_mac_001",
          "type": "process_manager",
          "preference": "launchd",
          "confidence": 1.0,
          "learned_from": "system_requirement"
        }
      ]
    }
  }
}
```

### Project Memory (existing)
```json
{
  "version": "1.0",
  "project": "/Users/yehosef/projects/legacy-monolith",
  "preferences": [
    {
      "id": "proj_001",
      "type": "data_storage",
      "preference": "local_files",
      "not": "redis",
      "reason": "Simple monolith, no Redis complexity needed",
      "confidence": 0.95,
      "learned_from": {
        "session": 23,
        "correction": "No Redis, use files instead",
        "context": "User explicitly rejected Redis for this codebase"
      },
      "created_at": "2025-10-15T14:00:00Z"
    }
  ]
}
```

---

## LLM Extraction Prompts

### Determining Scope

```python
SCOPE_DETECTION_PROMPT = """
Analyze this user correction and determine its scope.

Correction: {correction_text}
Project: {project_name}
Language: {primary_language}
Previous corrections: {previous_corrections}

Determine:
1. Is this preference GLOBAL (applies to all projects)?
2. Is this preference LANGUAGE-SPECIFIC (applies to all {language} projects)?
3. Is this preference PROJECT-SPECIFIC (applies only to {project})?
4. What is the confidence level (0.0-1.0)?

Factors:
- If user says "always" or "never" → likely GLOBAL
- If correction happens 3+ times across different projects → GLOBAL
- If correction happens 2+ times in same language → LANGUAGE-SPECIFIC
- If tied to existing codebase constraints → PROJECT-SPECIFIC
- If user provides project-specific reasoning → PROJECT-SPECIFIC

Return JSON:
{
  "scope": "global" | "language" | "project",
  "confidence": 0.0-1.0,
  "reasoning": "brief explanation",
  "preference": {
    "type": "...",
    "preference": "...",
    "not": "..." (optional)
  }
}
"""
```

### Cross-Project Pattern Detection

```python
PATTERN_DETECTION_PROMPT = """
Analyze these corrections across multiple projects:

{corrections_list}

Are these:
1. Same preference repeated → should be promoted to GLOBAL or LANGUAGE-SPECIFIC?
2. Context-dependent variations → should remain PROJECT-SPECIFIC?

Look for:
- Same technology rejected/preferred across projects
- Similar patterns in different contexts
- Language-specific vs language-agnostic patterns

Return JSON with promotion recommendation.
"""
```

---

## User Control & Transparency

### View Learned Preferences

**/amplicode-preferences**
```
📊 Your Learned Preferences

🌍 Global (all projects):
  • Communication: Concise, technical (confidence: 95%)
  • Code style: Descriptive variable names (confidence: 90%)

🐍 Python:
  • Test framework: pytest (confidence: 85%)
  • Async: asyncio, not twisted (confidence: 90%)

📁 This Project (legacy-monolith):
  • Data storage: local files, not Redis (confidence: 95%)
    Reason: "Simple monolith, no Redis complexity needed"
```

### Edit/Delete Preferences

**/amplicode-edit-preference [id]**
```
Editing: pref_001 (Communication style)

Current: "concise_technical" (confidence: 95%)
Learned from: 5 corrections across 3 projects

Options:
1. Keep as-is
2. Change confidence
3. Change scope (global → language → project)
4. Delete
```

### Explicit Learning

**/amplicode-learn**
```
User: /amplicode-learn "For all Python projects, use pytest"

✅ Learned:
   Scope: language (Python)
   Preference: pytest for test framework
   Confidence: 1.0 (explicit user instruction)
```

---

## Migration Path

### Week 1: Project-Only (MVP)
```
<project>/.data/memory.json
└── preferences[]
```

### Week 2: Add Global
```
~/.claude/global_memory.json
└── preferences[]

<project>/.data/memory.json
└── preferences[] (overrides global)
```

### Week 3: Add Context
```
~/.claude/global_memory.json
└── preferences[]

~/.claude/context_memory.json
└── contexts/
    ├── python/
    ├── javascript/
    └── platform:macos/

<project>/.data/memory.json
└── preferences[] (overrides both)
```

### Week 4: Auto-Promotion
```python
# Background worker task
def detect_promotion_candidates():
    # Find preferences repeated across projects
    candidates = find_repeated_preferences()

    for candidate in candidates:
        if candidate.count >= 3 and candidate.same_language:
            # Promote to language-specific
            promote_to_context(candidate, language=candidate.language)
            remove_from_projects(candidate)
        elif candidate.count >= 3 and candidate.cross_language:
            # Promote to global
            promote_to_global(candidate)
            remove_from_projects(candidate)
```

---

## Edge Cases & Challenges

### 1. Conflicting Patterns

**Problem:** User prefers Redis in project A, files in project B (both Python)

**Solution:** Keep both as project-specific, don't promote to language-level
```python
if has_conflicting_preferences(pref, language):
    keep_as_project_specific(pref)
    log_reason("Conflicting patterns detected")
```

### 2. Evolving Preferences

**Problem:** User used to prefer X, now prefers Y

**Solution:** Time-decay confidence, recent corrections weigh more
```python
def calculate_confidence(corrections):
    recent_weight = 0.7
    older_weight = 0.3

    recent = corrections[-5:]  # Last 5 corrections
    older = corrections[:-5]

    confidence = (
        (recent_weight * analyze(recent)) +
        (older_weight * analyze(older))
    )
```

### 3. False Positives

**Problem:** User rejected Redis once due to one-off reason, system learns "never Redis"

**Solution:** Require N confirmations before high confidence
```python
CONFIDENCE_THRESHOLDS = {
    1: 0.3,   # Single correction → low confidence
    2: 0.6,   # Two corrections → medium
    3: 0.8,   # Three corrections → high
    5: 0.95   # Five corrections → very high
}
```

### 4. Context Ambiguity

**Problem:** Is "use files not Redis" project-specific or global?

**Solution:** LLM analyzes user's reasoning
```python
if "this project" in correction or "legacy" in correction:
    scope = "project"
elif "always" in correction or "never" in correction:
    scope = "global"
else:
    scope = "uncertain"  # Ask user or keep project-specific by default
```

---

## Success Metrics

### Learning Effectiveness
- **Reduction in repeated corrections** - User corrects same thing fewer times over weeks
- **Cross-project preference application** - Global preferences auto-applied to new projects
- **Context accuracy** - Language-specific preferences applied to correct language only

### User Experience
- **Preference transparency** - User can view/edit all learned preferences
- **Scope clarity** - User understands why preference is global vs project-specific
- **Override ease** - User can easily override learned preferences when needed

### System Health
- **False positive rate** - <5% of learned preferences are incorrect
- **Conflict rate** - <10% of preferences have cross-project conflicts
- **Promotion accuracy** - >90% of promoted preferences are appropriate

---

## Recommendations

### Start Simple (Phase 1)
1. Implement **project-only** learning first
2. Validate correction pattern detection works
3. Build confidence in LLM extraction quality

### Add Hierarchy (Phase 2)
1. Add **global preferences**
2. Implement precedence: project > global
3. Manual promotion only (user can say "make this global")

### Add Intelligence (Phase 3)
1. Add **language/platform context**
2. Implement **auto-promotion** (3+ occurrences)
3. Build **conflict detection** and resolution

### Add Control (Phase 4)
1. Slash commands for viewing/editing preferences
2. Transparency in why preference was applied
3. Easy override mechanism

**Critical Success Factor:** The system must be transparent and controllable. Users should understand what was learned and be able to correct it easily.

---

## Comparison to Other Systems

| System | Levels | Override | Auto-Promotion | User Control |
|--------|--------|----------|----------------|--------------|
| **GitHub Copilot** | 3 (User/Org/Repo) | Repo > Org > User | No (manual files) | High (edit files) |
| **Cursor** | 2 (Global/Project) | Project > Global | No (manual files) | High (edit files) |
| **Amplicode (Proposed)** | 3 (Global/Lang/Project) | Project > Lang > Global | Yes (auto-detect) | High (slash commands) |

**Amplicode's advantage:** Automatic learning + hierarchical context + user control.

---

## Next Steps

1. **✅ Document this strategy** (this file)
2. **Implement Phase 1** - Project-only learning
3. **Gather user feedback** - Does project-only solve 80% of use cases?
4. **Implement Phase 2** - Add global if needed
5. **Iterate based on real usage patterns**

**Philosophy:** Start simple, learn from usage, add complexity only when justified by real user needs.
