---
name: implement-todo
description: "Implement engineering work from `todos/*.md` specs, especially plans produced by `write-todo`. Use when a task includes `## Spec` and `## Plan` and the goal is to execute each plan step faithfully while prioritizing intent, acceptance criteria, and the final manual QA gate."
---

# Implement Todo

Implement plan-driven work with high fidelity to the spec's intent.

## Workflow

1. Read `## Spec` and `## Plan` fully before writing code.
2. Extract the core intent from `## Spec` (`why`, expected outcome, build target, approach).
3. Treat the spec's spirit as the top priority; do not optimize for checkbox completion if it violates intent.
4. Execute plan steps in order unless a blocker requires reordering.
5. Map each implementation change back to the current step's acceptance criteria.

## Clarification Rules

- State uncertainty explicitly as soon as it appears.
- Ask clarifying questions instead of guessing when requirements are ambiguous or conflicting.
- Confirm backwards compatibility requirements with the user whenever they are not explicit.
- Pause and ask before large scope or architecture changes not implied by the spec.

## Quality Rules

- Write simple, testable, maintainable code.
- Avoid thrashing between approaches; choose one coherent path.
- Stop and confer with the user if implementation starts getting messy.
- Keep changes tightly scoped to the current plan step.

## Review Checkpoints

- Pause for code review every few steps (use judgment; default to every 2-3 steps).
- Also pause for review after risky changes (schema changes, refactors, behavior changes).
- During each checkpoint, verify:
  - alignment with spec intent
  - acceptance criteria status
  - regressions and test coverage for touched areas

## Completion Gate

1. Confirm every plan step's acceptance criteria are satisfied or explicitly deferred with rationale.
2. Ensure the final acceptance/manual QA step is prepared and surfaced to the user as the goal gate.
3. Report gaps clearly if anything remains unclear, unimplemented, or blocked.
