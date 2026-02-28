---
name: orchestrate-todo
description: "After a brainstorming session, write a todo spec, launch implementer + reviewer agents, and monitor the run to completion."
---

# Orchestrate Todo

End-to-end orchestration: write spec, launch agents, monitor, summarize.

## Phase 1: Write the Todo

Use the `write-todo` skill to produce `todos/<name>.md` from the current conversation. Present it to the user for review. Do not proceed until they approve.

## Phase 2: Configure the Run

Ask the user:
- **Agent harness**: `codex`, `claude`, `pi`, or `droid`
- **Reviewers**: 1 (default) or 2
- **Strictness**: `light`, `balanced` (default), `strict`, or `paranoid`

Pick a coord dir: `/tmp/orchestrate-<todo-name>-<epoch>`.

## Phase 3: Launch Agents

Use `<scripts>/launch-agent.sh` (in `scripts/` next to this file) to spawn agents.

Launch implementer first (it creates the coord dir). Wait 5 seconds, then launch reviewer(s).

Implementer prompt:
```
use implement-todo skill in <coord-dir> for <todo-file>
```

Reviewer prompt:
```
use review-todo skill in <coord-dir> for <todo-file>
```

Log files go to `/tmp/orchestrate-<todo-name>-impl.log` and `/tmp/orchestrate-<todo-name>-rev1.log`.

## Phase 4: Monitor

Poll every 30 seconds. For each poll:

1. Check processes are alive (`kill -0 <pid>`). If dead, report to user and offer to relaunch.
2. Read `<coord-dir>/state.md`. If `done`, go to Phase 5.
3. Count requests vs decisions to track progress.
4. Check heartbeat staleness (>5 min = flag).
5. Check for repeated REWORK on same step (3+ rounds = flag and ask user).

Keep the user updated with brief one-line progress reports. Only interrupt for problems.

## Phase 5: Summary

When the run finishes:

1. Report final status: steps completed, any that needed rework, total time.
2. Read through the coord dir artifacts (requests, reviews, decisions) for patterns.
3. Suggest concrete improvements to `implement-todo` or `review-todo` skills if you spotted recurring issues. No nitpicking — only material improvements that would change outcomes.
