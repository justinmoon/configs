---
name: review-todo
description: "Coordinate multi-agent code review for plan-driven implementation using a shared filesystem run directory and optional tmux layout. Use when one agent is implementing a todo spec and 2 reviewer agents should asynchronously review checkpoints, return verdicts, and drive next-step decisions with timeouts and round limits."
---

# Review Todo

Coordinate agents around a `todos/*.md` implementation run:
- one `implementer` agent (using `implement-todo`) — **always initializes the coordination directory**
- one or two reviewer agents (`reviewer-1`, `reviewer-2`) using this skill

Use this skill when you want review checkpoints without manual copy/paste between agents.

## Arguments

```
/review-todo <coord-dir> <todo-file> [reviewer-role]
```

- `coord-dir`: shared coordination directory (e.g. `/tmp/oc-tests`). The **implementer creates this**; the reviewer waits for it.
- `todo-file`: path to the `todos/*.md` spec file (for context).
- `reviewer-role`: `reviewer-1` (default) or `reviewer-2`.

## Scripts

All scripts are in `scripts/` next to this file. Resolve that absolute path first. We refer to it below as `<scripts>`.

## Behavior

**This is a long-running agent.** On startup, wait for the coordination directory, register, and immediately enter the reviewer loop. Keep looping until the run is marked done or the idle timeout fires. **Do NOT stop to ask the user if you should start reviewing. Just do it.**

## Startup

1. **Wait for the coordination directory** (the implementer creates it):
   ```bash
   while [ ! -f "<coord-dir>/meta.env" ]; do
     echo "Waiting for implementer to initialize <coord-dir>..."
     sleep 5
   done
   ```

2. **Register your role:**
   ```bash
   <scripts>/register-role.sh <coord-dir> <reviewer-role> <reviewer-role>
   ```

3. **Read the todo spec** so you understand what the implementer is building and what acceptance criteria to review against.

4. **Immediately enter the reviewer loop below.** Do not stop or ask for confirmation.

## Reviewer Loop

Run this loop **continuously until the run ends**:

1. **Poll for a pending request.** Do NOT use `watch-next-request.sh` (it blocks too long). Instead, poll manually:
   ```bash
   <scripts>/watch-next-request.sh <coord-dir> <reviewer-role> &
   WATCHER_PID=$!
   sleep 15
   kill $WATCHER_PID 2>/dev/null
   wait $WATCHER_PID 2>/dev/null
   ```
   Or, more simply, check the requests directory yourself:
   - Read `<coord-dir>/state.md` — if it says `done`, you're finished.
   - List files in `<coord-dir>/requests/` — find any `.md` file.
   - For each request file, check if `<coord-dir>/decisions/<request-id>.md` already exists (skip if so).
   - Check if `<coord-dir>/reviews/<request-id>/<reviewer-role>.md` already exists (skip if so — you already reviewed it).
   - If you find an unreviewed request with no decision, proceed to step 2.
   - If no pending requests, **sleep 10 seconds and check again**. Do not give up. Keep polling.

2. Read the request file. Review the implementation changes against the spec's acceptance criteria for that step. Read the actual changed files in the repo to assess quality.

3. Post your verdict:
   ```bash
   REVIEW_FILE=$(<scripts>/post-review.sh <coord-dir> <reviewer-role> <request-id> <verdict>)
   ```
   `verdict` values: `APPROVE`, `CHANGES_REQUESTED`, `BLOCKED`, `GIVE_UP`

4. Write your review content into the review file with concrete findings, file paths, and expected changes.

5. **Go back to step 1.** Keep looping until `state.md` says `done`.

## Review Policy

- Use strictness from run metadata as baseline, then apply reviewer judgment.
- Review incrementally by default; for final completion checkpoint, review the whole implementation (`scope: full`).
- Be generous but bounded: default max rounds per step is `7`.

## Timeouts And Loops

- Implementer review wait timeout: 20 minutes (default `1200s`).
- Reviewer idle give-up timeout: 1 hour (default `3600s`) without implementer heartbeat/progress.
- Round limit per step: default `7`. On limit breach without approval, escalate.

Timeout behavior:
- If only one review arrives by implementer timeout and it is `APPROVE`, default decision is `PROCEED_TIMEOUT`.
- Otherwise timeout leads to `GIVE_UP` or stronger decision (`REWORK` / `ESCALATE`) if a blocking review exists.

## Status

Inspect current run state anytime:

```bash
<scripts>/status.sh <run-dir>
```

## File Reference

See `references/protocol.md` for file layout and decision rules.
