---
name: global-agents-md
description: Add global agents reference to a repo. Use when initializing a repo for AI agent collaboration or when asked to set up AGENTS.md.
---

# global-agents-md

Add reference to `~/configs/GLOBAL-AGENTS.md` at top of repo's AGENTS.md.

## Purpose

GLOBAL-AGENTS.md contains best practices shared across all repos—avoids manual copy-paste of common agent instructions everywhere.

## Behavior

1. If no AGENTS.md exists: create with single reference line
2. If AGENTS.md exists: prepend reference line (skip if already present)

## Reference line

```
Read `~/configs/GLOBAL-AGENTS.md` before anything (skip if missing).
```

## After

Symlink CLAUDE.md for Claude Code compatibility if not such symlink exists already:

```bash
ln -sf AGENTS.md CLAUDE.md
```
