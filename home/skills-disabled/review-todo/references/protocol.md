# Review Todo Protocol

## Directory Structure

```
review-run/
├── meta.env
├── meta.md
├── state.md
├── roles/
│   ├── implementer.env
│   ├── reviewer-1.env
│   └── reviewer-2.env
├── heartbeats/
│   └── implementer.epoch
├── requests/
│   └── <step-id>-round-<NN>.md
├── reviews/
│   └── <request-id>/
│       ├── reviewer-1.md
│       └── reviewer-2.md
└── decisions/
    └── <request-id>.md
```

## Request Lifecycle

1. Implementer posts checkpoint with `post-checkpoint.sh`.
2. Reviewers discover pending request with `watch-next-request.sh`.
3. Each reviewer creates one review file with `post-review.sh`.
4. Implementer runs `wait-for-reviews.sh` to await reviews and produce decision.
5. Implementer follows decision:
   - `PROCEED` / `PROCEED_TIMEOUT` => next plan step
   - `REWORK` => same step, next round
   - `ESCALATE` / `GIVE_UP` => ask user
6. Implementer marks run complete with `finish.sh` once work is done.

## Decision Rules

Priority order:
1. Any `BLOCKED` => `ESCALATE`
2. Any `CHANGES_REQUESTED` => `REWORK`
3. Both `APPROVE` => `PROCEED`
4. Timeout with one `APPROVE` + one missing/`GIVE_UP` => `PROCEED_TIMEOUT`
5. Timeout with no usable approval => `GIVE_UP`

Round guard:
- If non-proceeding result and current round >= `max_rounds_per_step`, force `ESCALATE`.

## Strictness Profiles

- `light`: block only correctness, severe regressions, and security hazards
- `balanced`: block material quality/test gaps and correctness issues
- `strict`: include maintainability/design rigor and broader regression concerns
- `paranoid`: demand explicit evidence, edge-case handling, and test depth

## Review File Format

Every review file must start with:

```markdown
# Review: <request-id>

## Verdict: APPROVE | CHANGES_REQUESTED | BLOCKED | GIVE_UP
```

Then include concrete findings, file paths, and expected changes.
