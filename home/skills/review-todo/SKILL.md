---
name: review-todo
description: "Coordinate multi-agent code review for plan-driven implementation using a shared filesystem run directory and optional tmux layout. Use when one agent is implementing a todo spec and 2 reviewer agents should asynchronously review checkpoints, return verdicts, and drive next-step decisions with timeouts and round limits."
---

# Review Todo

Coordinate three agents around a `todos/*.md` implementation run:
- one `implementer` agent (typically using `implement-todo`)
- two reviewer agents (`reviewer-1`, `reviewer-2`) using this skill

Use this skill when you want review checkpoints without manual copy/paste between agents.

## Scripts

All scripts are in `scripts/` next to this file. Resolve that absolute path first. We refer to it below as `<scripts>`.

## Run Directory

The user provides the run directory path (same style as `consult`/`negotiate`).

Example:
- run dir: `./.coord/review-feature-x`
- todo spec: `./todos/feature-x.md`

## Quick Start

1. Launch tmux layout and initialize run metadata:

```bash
<scripts>/launch-tmux.sh <run-dir> <todo-file> [strictness] [review-guidance]
```

`strictness` values: `light`, `balanced`, `strict`, `paranoid`.

This script:
- initializes the run directory
- creates one tmux window with 3 panes
- prints role-specific commands in each pane
- does **not** auto-launch agents

2. Each agent claims one role:

```bash
<scripts>/register-role.sh <run-dir> implementer <agent-name>
<scripts>/register-role.sh <run-dir> reviewer-1 <agent-name>
<scripts>/register-role.sh <run-dir> reviewer-2 <agent-name>
```

## Implementer Workflow

Use `implement-todo` for coding, and this skill for checkpoints.

1. Post a review request when a step checkpoint is ready:

```bash
<scripts>/post-checkpoint.sh <run-dir> <step-id> [incremental|full]
```

`step-id` should match the todo plan step conceptually, e.g. `step-2-contracts`.
The script prints both `request-id` and `request-file`.

2. Fill the request file. Include:
- what step and acceptance criteria you believe are complete
- files changed
- tests run
- known risks/gaps

3. Wait for reviews and decision:

```bash
<scripts>/wait-for-reviews.sh <run-dir> <request-id>
```

Decision outcomes:
- `PROCEED` or `PROCEED_TIMEOUT` -> move to next plan step
- `REWORK` -> stay on same step, post a new round
- `ESCALATE` -> stop and ask user
- `GIVE_UP` -> stop due missing reviews and ask user

4. If coding for a long time before next checkpoint, keep heartbeat alive:

```bash
<scripts>/heartbeat.sh <run-dir>
```

5. When the todo is complete, mark the run done so reviewers can exit cleanly:

```bash
<scripts>/finish.sh <run-dir>
```

## Reviewer Workflow

Run this loop continuously:

1. Wait for next unreviewed request:

```bash
<scripts>/watch-next-request.sh <run-dir> reviewer-1
# or reviewer-2
```

Exit codes:
- `0` -> request is ready to review
- `2` -> run marked done
- `3` -> no implementer progress for idle timeout window (default 1 hour), reviewer should give up

2. Write review file:

```bash
REVIEW_FILE=$(<scripts>/post-review.sh <run-dir> reviewer-1 <request-id> <verdict>)
```

`verdict` values:
- `APPROVE`
- `CHANGES_REQUESTED`
- `BLOCKED`
- `GIVE_UP`

3. Fill review content in that file.

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
