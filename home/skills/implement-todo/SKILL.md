---
name: implement-todo
description: "Implement engineering work from `todos/*.md` specs, especially plans produced by `write-todo`. Use when a task includes `## Spec` and `## Plan` and the goal is to execute each plan step faithfully while prioritizing intent, acceptance criteria, and the final manual QA gate."
---

# Implement Todo

Implement plan-driven work with high fidelity to the spec's intent.

## Arguments

```
/implement-todo <coord-dir> <todo-file>
```

- `coord-dir`: shared coordination directory (e.g. `/tmp/oc-tests`). The implementer **always creates this** on startup so reviewers can find it.
- `todo-file`: path to the `todos/*.md` spec file.

The user may also specify the number of reviewers. **Default to 1 reviewer if not mentioned.**

## Scripts

`<scripts>` refers to the `scripts/` directory inside the `review-todo` skill. Resolve its absolute path from the skill registry before using any script commands.

## Startup

Run these two commands **sequentially** (init must finish before register):

```bash
<scripts>/init.sh --dir <coord-dir> --todo <todo-file> --reviewer-count <N>
<scripts>/register-role.sh <coord-dir> implementer implementer
```

`--reviewer-count` defaults to 1 if the user didn't specify. If `init.sh` exits with code 3 (already initialized), that's fine — continue to register.

## Workflow

1. Read `## Spec` and `## Plan` fully before writing code.
2. Extract the core intent from `## Spec` (`why`, expected outcome, build target, approach).
3. Treat the spec's spirit as the top priority; do not optimize for checkbox completion if it violates intent.
4. Execute plan steps in order unless a blocker requires reordering.
5. Map each implementation change back to the current step's acceptance criteria.

## Autonomy Rules

**This agent runs autonomously. Never stop to ask the user questions.** Make reasonable decisions and keep moving. If you encounter ambiguity (e.g. pre-existing files, unclear requirements), make your best judgment call and document what you chose in the checkpoint request file. The reviewer will catch mistakes.

- If you find pre-existing work that overlaps with your task, build on it.
- If a requirement is ambiguous, pick the simplest reasonable interpretation.
- If something is blocked, skip it, note it in the checkpoint, and move to the next step.

## Quality Rules

- Write simple, testable, maintainable code.
- Avoid thrashing between approaches; choose one coherent path.
- Stop and confer with the user if implementation starts getting messy.
- Keep changes tightly scoped to the current plan step.

## Review Checkpoints — CRITICAL

**You MUST post a checkpoint after EVERY plan step.** Do not batch multiple steps. Do not skip checkpoints. The reviewer agent is blocked waiting for your checkpoint — if you don't post one, the reviewer sits idle forever.

After completing each plan step:

1. Run `post-checkpoint.sh` to create the review request:
   ```bash
   <scripts>/post-checkpoint.sh <coord-dir> <step-id>
   ```
   This prints a `request-id` and `request-file`.

2. **Write the request file** with:
   - which plan step you completed
   - acceptance criteria you believe are met
   - files changed
   - tests run (if any)
   - known risks/gaps

3. **Wait for the reviewer verdict** (this blocks until the reviewer responds):
   ```bash
   <scripts>/wait-for-reviews.sh <coord-dir> <request-id>
   ```

4. **Follow the decision:**
   - `PROCEED` / `PROCEED_TIMEOUT` → move to next plan step
   - `REWORK` → fix issues, post a new checkpoint for the same step
   - `ESCALATE` → stop and ask user

5. **Repeat** for the next plan step. Every step gets a checkpoint. No exceptions.

6. When **all steps are done**, mark the run finished so the reviewer exits cleanly:
   ```bash
   <scripts>/finish.sh <coord-dir>
   ```

## Completion Gate

1. Confirm every plan step's acceptance criteria are satisfied or explicitly deferred with rationale.
2. Ensure the final acceptance/manual QA step is prepared and surfaced to the user as the goal gate.
3. Report gaps clearly if anything remains unclear, unimplemented, or blocked.
