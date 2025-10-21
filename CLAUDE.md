# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Amplicode** transforms Claude Code from a helpful AI assistant into a **force multiplier** by providing the environment that makes AI 10x more capable. Inspired by [Microsoft Amplifier](https://github.com/microsoft/amplifier), it addresses the fundamental constraint: **"I have more ideas than time to try them out."**

### Core Insight
The bottleneck isn't AI capability—it's lack of context, domain knowledge, patterns, and ability to work in parallel. Amplicode solves this through:
- **Specialized agents** for focused expertise
- **Persistent knowledge** that compounds over time
- **Structured workflows** for complex tasks
- **Parallel exploration** of solution spaces
- **Memory systems** that preserve learning across sessions

## Project Structure

### Core Directories
- `.claude/` - Project-specific Claude configuration and context
  - `.claude/agents/` - Specialized AI agents (markdown-based)
  - `.claude/commands/` - Custom slash commands for workflows
  - `.claude/tools/` - Automation scripts and hooks
  - `.claude/notes/` - Documentation, session notes, and design decisions
  - `.claude/resume.md` - Session handoff instructions (auto-generated)
  - `.claude/session-tasks.md` - Current work tracking (auto-generated)
  - `settings.json` - Hooks, permissions, MCP configuration
- `amplicode/` - Core Python implementation
  - `memory/` - Persistent memory system
  - `knowledge/` - Knowledge extraction and synthesis
  - `agents/` - Agent orchestration
  - `workflows/` - Structured workflow patterns
- `.data/` - Runtime data (gitignored)
  - `transcripts/` - Conversation exports
  - `memory.json` - Persistent memory storage
  - `knowledge/` - Extracted knowledge graphs

### Architecture (Phased Implementation)

**Phase 1: Foundation (Weeks 1-4)**
1. **Agent System** - Markdown-based specialized agents with mode-driven operation
2. **Transcript Export** - Pre-compaction hooks preserve full context
3. **Basic Memory** - Pattern-based extraction to local JSON storage
4. **Tool Templates** - Standard patterns for reliable tool generation

**Phase 2: Knowledge (Weeks 5-8)**
1. **Extraction** - Extract concepts, relations, entities from documents
2. **Synthesis** - Identify cross-source patterns and tensions
3. **Storage** - Single JSONL file (ruthless simplicity)
4. **Querying** - Semantic search and basic graph visualization

**Phase 3: Workflows (Weeks 9-12)**
1. **Recipe System** - Metacognitive workflows (code + AI)
2. **Modular Builder** - Contract-first code generation
3. **Document-Driven Development** - Five-phase workflow
4. **Validation** - Philosophy compliance checking

**Phase 4: Parallel (Weeks 13-16)**
1. **Worktree Integration** - Test multiple approaches simultaneously
2. **Parallel Agent Execution** - Concurrent specialized agents
3. **Variant Comparison** - Systematic evaluation framework
4. **Learning Extraction** - Capture and codify what works

## Development Setup

### Technology Stack
- **Primary Language**: Python 3.11+ (for knowledge/memory systems, matching Amplifier's choice)
- **Package Manager**: uv (fast, reliable dependency management)
- **Agent Definition**: Markdown files in `.claude/agents/`
- **Storage**: Local JSON/JSONL files (ruthless simplicity over databases)
- **Testing**: pytest with emphasis on integration tests

### Initial Setup Commands
```bash
# Create virtual environment
python -m venv .venv
source .venv/bin/activate

# Install uv
pip install uv

# Install dependencies (once pyproject.toml exists)
uv pip install -e .

# Run checks
make check  # lint, format, type check
make test   # run tests
```

## Core Design Principles

### 1. Ruthless Simplicity
**Guiding Question**: "Is this the simplest thing that could work?"

- Minimize abstractions - every layer must justify existence
- Start minimal, grow as needed
- Avoid future-proofing for hypothetical requirements
- Code you don't write has no bugs
- Trust in emergence over imposed complexity

**Example Pattern (GOOD):**
```python
class SimpleManager:
    def __init__(self):
        self.items = {}  # Simple dict, not complex registry

    def add(self, key, value):
        self.items[key] = value  # Direct, obvious
```

**Anti-Pattern (BAD):**
```python
class OverEngineeredRegistry:
    def __init__(self, metrics, cleanup_interval=60):
        self.items_by_id = {}
        self.items_by_type = defaultdict(list)
        self.metrics = metrics
        self.cleanup_task = asyncio.create_task(...)
        # 50+ lines of complex indexing
```

### 2. Modular "Bricks & Studs" Architecture
**Vision**: Modules ~150 lines that AI can regenerate entirely instead of patching.

**Pattern:**
1. **Brick** = Self-contained directory, single responsibility
2. **Stud** = Public contract (function signatures, data models)
3. **Start with contract** - README/docstring defines: purpose, inputs, outputs, side-effects, dependencies
4. **Build in isolation** - Code + tests + fixtures in brick's folder
5. **Expose only contract** - Via `__all__` or interface file
6. **Regenerate, don't patch** - Rewrite whole brick from spec when changes needed

**Human ↔️ AI Handshake:**
- Human: Writes/tweaks specs, reviews behavior
- Agent: Generates brick, runs tests, reports results
- Humans rarely read code unless tests fail

### 3. Zero-BS Principle: No Stubs or Placeholders
**Rule**: Every function must work or not exist. Every file complete or not created.

**NEVER write without implementation:**
- `raise NotImplementedError` (except in abstract base classes)
- `TODO` comments without accompanying code
- `pass` as placeholder (except framework requirements)
- `return {}  # stub`
- `...` as implementation

**Instead:**
- Use file-based storage instead of databases
- Use local processing instead of external APIs
- Build simplest working version
- Ask for details if requirements vague
- Reduce scope to achievable functionality

### 4. Analysis-First Development
**Pattern**: When given complex task → FIRST respond: "Let me analyze this problem before implementing"

**Structured Output:**
1. **Problem decomposition** - Break into manageable pieces
2. **Approach options** - 2-3 solutions with trade-offs
3. **Recommendation** - Clear choice with justification
4. **Implementation plan** - Step-by-step approach

**When to use:**
- New feature implementation
- Complex refactoring
- Performance optimization
- Architecture decisions
- Integration with external systems

**When to skip:**
- Simple typo fixes
- Straightforward CRUD
- Well-defined, isolated changes

## Development Workflow

### Planning Pattern
1. **Ultra-think before building** - Deep analysis of goals, constraints, challenges
2. **Create design documents** - In `.claude/notes/` for major decisions
3. **Use TodoWrite** - Track all multi-step work with specific tasks
4. **Update immediately** - Mark tasks completed as you finish them
5. **Create resume instructions** - Before breaks or `/clear` for continuity

### Task Organization
Always organize by priority:
- 🚨 **CRITICAL**: Security, data loss risks, system crashes
- ⚠️ **HIGH**: Core functionality, performance, reliability
- 📝 **MEDIUM**: Code quality, optimization, technical debt
- 🧹 **LOW**: Documentation, cleanup, nice-to-haves

### Code Organization
- **Modular architecture** - Self-contained bricks with clear contracts
- **~150 lines per module** - AI-regeneratable size
- **Integration points documented** - Clear interfaces between components
- **Separation of concerns** - Core vs extensions, data vs logic

### Defensive Utilities (Critical for LLM Integration)
When working with LLM responses, always use defensive utilities:

```python
from amplicode.utils.defensive import (
    parse_llm_json,      # Extract JSON from any format
    retry_with_feedback, # Intelligent retry with error correction
    isolate_prompt       # Prevent context contamination
)

# Don't assume perfect JSON
result = parse_llm_json(llm_response)

# Retry with feedback on errors
result = await retry_with_feedback(
    async_func=generate_synthesis,
    prompt=prompt,
    max_retries=3
)
```

### Tool Generation Checklist
Every generated tool must:
- [ ] Use recursive glob patterns (`**/*.md` not `*.md`)
- [ ] Validate minimum inputs before processing
- [ ] Show clear progress/activity to user
- [ ] Fail fast with descriptive errors
- [ ] Use defensive utilities from toolkit
- [ ] Handle cloud sync delays (retry with backoff)

## Agent System Guidelines

### Creating Agents
Agents are markdown files in `.claude/agents/` with frontmatter:

```markdown
---
name: agent-name
description: When and how to use this agent. Be specific about triggers.
model: inherit
---

You are [Agent Name], specialized in [domain].

**Core Philosophy:**
[Key principles this agent follows]

**Operating Modes:**
[Different modes based on task context]

## Mode 1: [Name]
[When this mode activates]
[What this mode does]
[Output format]

## Mode 2: [Name]
...
```

### Agent Invocation
Main Claude Code instance should proactively delegate to specialized agents:
- Use Task tool with subagent_type
- Launch multiple agents in parallel when possible (single message, multiple Task calls)
- Each agent conserves context by returning only essential results

### Core Agents (Phase 1)
1. **architect** - Analysis-first design, architecture planning, code review
2. **builder** - Contract-first implementation following modular pattern
3. **reviewer** - Philosophy compliance, quality assessment

## Key Learnings from Amplifier

### What Works
1. **Specialized agents** - Domain expertise beats generalist AI
2. **Pattern-based memory** - Simple extraction is reliable
3. **JSONL storage** - Simplicity beats vector databases
4. **Transcript export** - Prevents context loss
5. **Analysis-first** - Better decisions, fewer rewrites

### What to Avoid
1. **Over-engineering** - Complex abstractions without value
2. **Stubs/placeholders** - Build working code or nothing
3. **Monolithic tools** - Break into composable pieces
4. **Silent failures** - Always show what's happening
5. **Non-recursive globs** - Use `**/*` for nested structures

### Common Pitfalls
From Amplifier's DISCOVERIES.md:
- Cloud sync can cause I/O errors (add retry logic)
- LLMs don't return perfect JSON (use defensive parsing)
- Context contamination (isolate prompts)
- Tool generation predictable failures (use checklist)
- Missing input validation (check before processing)

## Reference Materials

### Primary Sources
- [Microsoft Amplifier Repository](https://github.com/microsoft/amplifier) - Cloned at `/Volumes/code/github/amplifier`
- [Deep Analysis](./.claude/notes/amplifier-deep-analysis.md) - Comprehensive research on Amplifier's architecture
- [Project Vision](./.claude/notes/project-vision.md) - Amplicode goals and decisions

### Claude Documentation
- [Claude Code Documentation](https://docs.claude.com/en/docs/claude-code)
- Agent creation patterns from Amplifier's `.claude/agents/`
- Tool development from Amplifier's `scenarios/`

## Differentiation from Amplifier

### Our Advantages
1. **Multi-model support** - Claude, GPT-4, local models from day one
2. **Better safety** - Granular permissions, per-agent allowlists
3. **Cross-platform** - Equal macOS/Linux/WSL2 support from start
4. **Simpler onboarding** - One-command bootstrap, sensible defaults
5. **Community-first** - Built for sharing agents, recipes, patterns

### Our Constraints
1. **Later to market** - They have head start, but we learn from their discoveries
2. **Solo/small team** - Offset with open source community
3. **Need to prove improvements** - Show value through demos

## Project Status

**Current Phase**: Research complete, ready to begin Phase 1 implementation

**Next Steps**:
1. Initialize Python project structure (pyproject.toml, Makefile)
2. Create first three agents (architect, builder, reviewer)
3. Implement transcript export hook
4. Build basic memory pattern extraction

**Success Criteria**:
- Agents can be invoked and work in parallel
- Context preserved across compaction
- Basic learnings persist between sessions
- First tool generates successfully using checklist
