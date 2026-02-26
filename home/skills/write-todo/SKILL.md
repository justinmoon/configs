---
name: write-todo
description: Turn a user request (often after a long planning session) into a concrete todo spec in `todos/` with two sections: Spec and Plan. Plan must use numbered steps with acceptance criteria and end with a user-run manual QA gate.
---

# write-todo

Create a practical implementation spec file under `./todos/` based on a planning discussion.

Use this when the user says things like:
- "write a todo/spec"
- "turn this into a plan"
- "document implementation steps"

## Output Contract

The spec must:
- Be written to `todos/<descriptive-kebab-name>.md`
- Have exactly two top-level sections: `## Spec` and `## Plan`
- In `## Spec`, clearly state:
  - why this is being done
  - intent and expected outcome
  - exact build target (what will exist when done)
  - exact approach (how it will be accomplished at a technical level)
- In `## Plan`:
  - Write step-by-step implementation plan to build the spec.
  - Use **incrementing steps** (`1.`, `2.`, `3.`) only
  - Include **acceptance criteria** for each step
  - Include a **final step** that is explicitly **manual QA (user-run)** if possible
  - Keep intermediate QA mostly agent-run sanity checks (do not over-burden the user)
- Do **not** include time in implementation plans (no weeks, dates, estimates, or timelines)

## Style Rules

- Keep steps concrete and implementation-ready.
- Prefer contract-first sequencing before deep implementation.
- Include rollback/safety where relevant.
- Ensure you know whether where backwards compatibility is and isn't required
- Avoid fluff, avoid vague “investigate” steps unless scoped and testable.
- Make `Spec` specific enough that a different engineer / agent could build the same thing.

