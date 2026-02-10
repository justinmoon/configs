---
name: agents-md
description: Bootstrap or improve a repo's AGENTS.md with best practices — global reference, agent-brief script, docs scaffolding, CLAUDE.md symlink. Use when initializing or upgrading AGENTS.md for AI agent collaboration.
---

# agents-md

Set up AGENTS.md best practices for a repo. Combines global reference, live agent-brief script, docs scaffolding, and Claude Code compatibility.

## Steps

### 1. Global reference line

Prepend this line to AGENTS.md (create file if missing; skip if already present):

```
Read `~/configs/GLOBAL-AGENTS.md` (fallback: https://raw.githubusercontent.com/justinmoon/configs/master/GLOBAL-AGENTS.md). Skip if both unavailable.
```

### 2. agent-brief script

Create `scripts/agent-brief` (executable). This script prints a live context snapshot for AI agents at session start. It runs commands in parallel and prints grouped output.

The script must collect and run these sections:

| Section | Command | Purpose |
|---------|---------|---------|
| just commands | `just --list` | Available tasks |
| docs | `npx -y @justinmoon/docs-list` | Docs index with summaries and "read when" hints |
| pika-cli help | `cargo run -q -p pika-cli -- --help` | CLI subcommands (adapt binary name per project) |
| agent-device help | `npx --yes agent-device --help` | Device automation tool for QA |

Adapt the sections to match what the project actually has:
- Only include `pika-cli` (or equivalent) if the project has a CLI binary
- Only include `agent-device` if the project uses mobile device testing
- Only include `npx -y @justinmoon/docs-list` if a `docs/` directory exists
- Always include `just --list` if a justfile exists

Use the monorepo `agent-brief` as a template (at `~/code/monorepo/scripts/agent-brief`), but simplify — no app/project argument needed for single-app repos. Keep the parallel execution pattern.

**Template structure:**

```bash
#!/usr/bin/env bash
set -u -o pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

titles=()
cmds=()
descs=()

# --- Commands ---
titles+=("just commands")
cmds+=("just --list")
descs+=("Available tasks.")

# --- Docs ---
# Only if docs/ exists
if [[ -d "${repo_root}/docs" ]]; then
  titles+=("Docs")
  cmds+=("npx -y @justinmoon/docs-list")
  descs+=("Project documentation index.")
fi

# --- CLI help ---
# Adapt: use the project's actual CLI binary
titles+=("pika-cli help")
cmds+=("cargo run -q -p pika-cli -- --help")
descs+=("Marmot protocol CLI for testing and agent automation.")

# --- Device automation ---
titles+=("agent-device help")
cmds+=("npx --yes agent-device --help")
descs+=("Device automation for manual QA on iOS/Android.")

# Run all in parallel, collect output, print grouped results
# (copy the parallel execution + output pattern from ~/code/monorepo/scripts/agent-brief)
```

### 3. AGENTS.md brief instruction

Add this section to AGENTS.md (after the global reference line, before project-specific content):

```markdown
Run `./scripts/agent-brief` first thing to get a live context snapshot.
```

### 4. Docs scaffolding

Create `docs/` directory if it doesn't exist. Add one starter doc to verify `docs-list` works:

**`docs/architecture.md`:**
```markdown
---
summary: High-level architecture — Rust core, iOS/Android apps, MLS over Nostr
read_when:
  - starting work on the project
  - need to understand how components fit together
---

# Architecture

(Fill in project-specific architecture details.)
```

Only create starter docs if `docs/` doesn't already exist. Never overwrite existing docs.

### 5. Remove stale inline help from AGENTS.md

If AGENTS.md contains inline CLI usage examples (like `pika-cli` invocations), remove them — agent-brief now provides live help. Replace with a pointer:

```markdown
## CLI

Run `./scripts/agent-brief` for current CLI help. State persists in `--state-dir` between runs.
```

### 6. CLAUDE.md symlink

Create symlink for Claude Code compatibility (skip if already exists):

```bash
ln -sf AGENTS.md CLAUDE.md
```

## Verification

After all changes, run:

```bash
./scripts/agent-brief
npx -y @justinmoon/docs-list
```

Confirm both produce clean output. Fix any errors before finishing.
