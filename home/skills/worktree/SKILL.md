---
name: worktree
description: Build features in git worktrees. Creates a worktree, opens a new tmux window, and launches a SEPARATE AI agent with the prompt. Use when planning is complete and implementation should happen in isolation. IMPORTANT - you must launch a new agent, not implement yourself.
---

# Build in Worktree

Spawn a feature implementation in an isolated git worktree with a **SEPARATE** AI agent.

## CRITICAL: You Are the Planner, Not the Implementer

When using this skill:
1. You (the planning agent) create the worktree and tmux window
2. You launch a NEW agent (codex/claude/etc) in that tmux window
3. **YOU STOP.** Your job is done. Do NOT implement the feature yourself.
4. Report back to the user that the agent has been launched

The new agent will do the implementation work. You do NOT follow it into the worktree.

## How to Execute

**ALWAYS use the script** - it handles everything correctly:

```bash
~/configs/agent/skills/worktree/scripts/build-in-worktree.sh "<detailed prompt>" [agent]
```

The script will:
1. Create the worktree
2. Open tmux window
3. Run direnv allow
4. **Launch the agent with the prompt** (this is the critical step you're here for)

## IMPORTANT: Write Thorough Prompts

The prompt becomes the new agent's ONLY context. Be extremely detailed:

**Bad prompt:**
> "Add dark mode"

**Good prompt:**
> "Implement dark mode toggle for the settings page. Requirements:
> - Add a toggle switch in src/components/Settings.tsx
> - Store preference in localStorage with key 'theme'
> - Use CSS variables defined in src/styles/variables.css
> - Support 'light', 'dark', and 'system' modes
> - Apply theme by adding data-theme attribute to document.body
> - Follow existing button styling patterns in the codebase
> - Add E2E test in tests/settings.spec.ts
> Reference the existing color scheme implementation in src/hooks/useTheme.ts"

Include:
- Specific files to modify
- Technical requirements
- Patterns to follow
- Tests to add
- Any relevant context

## Agent Options

- `codex` (default) - launches with `--yolo`
- `claude` - launches with `--dangerously-skip-permissions`
- `opencode` - launches with `--yolo`
- `droid` - launches as-is
- `pi` - launches as-is

## Example

```bash
~/configs/agent/skills/worktree/scripts/build-in-worktree.sh "Implement pgBackRest backups for PostgreSQL. Add NixOS module at infra/nix/modules/pgbackrest.nix with options for S3 bucket, retention, schedules. Wire into prod.nix. Add secrets via agenix. Include systemd timers for full/diff backups. Reference existing postgres.nix patterns." codex
```

Then tell the user: "Launched codex in worktree `pgbackrest-backups`. It will implement the feature."

## DO NOT

- Do NOT manually run git worktree commands
- Do NOT manually run tmux commands
- Do NOT implement the feature yourself after creating the worktree
- Do NOT cd into the worktree and start coding

Just run the script, confirm it worked, and report back to the user.
