---
name: diagram
description: Render Mermaid diagrams as ASCII art in the terminal or as beautiful themed SVGs. Use when you need to visualize architecture, data flows, state machines, sequences, class hierarchies, or ER models. Supports flowcharts, sequence diagrams, state diagrams, class diagrams, and ER diagrams.
---

# Diagram

Render Mermaid diagrams using [beautiful-mermaid](https://github.com/lukilabs/beautiful-mermaid). Outputs ASCII art for inline terminal display or themed SVGs for files.

## Rendering Diagrams

No setup needed — `beautiful-mermaid` is auto-installed on first run via `bun --install=fallback`.

### ASCII to Terminal (default — use this for quick inline diagrams)

```bash
bun ~/configs/home/skills/diagram/scripts/render.ts "<mermaid source>"
```

Or from a `.mmd` file:

```bash
bun ~/configs/home/skills/diagram/scripts/render.ts diagram.mmd
```

### SVG to File

```bash
bun ~/configs/home/skills/diagram/scripts/render.ts diagram.mmd --svg output.svg --theme tokyo-night
bun ~/configs/home/skills/diagram/scripts/render.ts diagram.mmd --svg output.svg --theme catppuccin-mocha --open
```

### Options

| Flag | Description |
|------|-------------|
| `--svg <file>` | Write SVG to file instead of ASCII to stdout |
| `--theme <name>` | Built-in theme for SVG (default: `zinc-dark`) |
| `--ascii` | Use plain ASCII instead of Unicode box-drawing |
| `--transparent` | Transparent SVG background |
| `--open` | Open SVG in browser after rendering |

### Available Themes

`zinc-light`, `zinc-dark`, `tokyo-night`, `tokyo-night-storm`, `tokyo-night-light`, `catppuccin-mocha`, `catppuccin-latte`, `nord`, `nord-light`, `dracula`, `github-light`, `github-dark`, `solarized-light`, `solarized-dark`, `one-dark`

## Workflow

1. **Write the Mermaid source** — either inline as a string or save to a `.mmd` file
2. **Render ASCII first** to verify the diagram is correct (fast, visible inline)
3. **Render SVG** if the user needs a file, wants theming, or needs to share it

Always show the ASCII output to the user so they can see the diagram immediately.

## Mermaid Syntax Quick Reference

### Flowchart

```
graph TD
    A[Start] --> B{Decision}
    B -->|Yes| C[Process]
    B -->|No| D[End]
    C --> D
```

Directions: `TD` (top-down), `LR` (left-right), `BT` (bottom-top), `RL` (right-left)

Node shapes: `[rectangle]`, `{diamond/decision}`, `(rounded)`, `([stadium])`, `[[subroutine]]`, `[(cylinder)]`, `((circle))`, `>asymmetric]`, `{hexagon}`, `[/parallelogram/]`

### Sequence Diagram

```
sequenceDiagram
    Alice->>Bob: Hello
    Bob-->>Alice: Hi back
    Alice->>Bob: How are you?
    Note right of Bob: Thinking...
    Bob-->>Alice: Great!
```

Arrow types: `->>` (solid), `-->>` (dashed), `-x` (cross), `--x` (dashed cross)

### State Diagram

```
stateDiagram-v2
    [*] --> Idle
    Idle --> Processing: start
    Processing --> Complete: done
    Processing --> Error: fail
    Error --> Idle: retry
    Complete --> [*]
```

### Class Diagram

```
classDiagram
    Animal <|-- Duck
    Animal <|-- Fish
    Animal: +int age
    Animal: +isMammal() bool
    Duck: +swim()
    Fish: +breatheUnderwater()
```

Relationships: `<|--` (inheritance), `*--` (composition), `o--` (aggregation), `-->` (association), `..>` (dependency), `..|>` (realization)

### ER Diagram

```
erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ LINE_ITEM : contains
    PRODUCT ||--o{ LINE_ITEM : "is in"
```

Cardinality: `||` (exactly one), `o|` (zero or one), `}|` (one or more), `}o` (zero or more)

## Important Notes

- Mermaid source must use **newlines** between statements (not semicolons) for ASCII rendering — the script auto-converts single-line semicolon syntax
- ASCII rendering is **synchronous and fast** — prefer it for quick visualization
- SVG rendering is async but still sub-second
- When the user asks to "draw", "diagram", "visualize", or "show me" something architectural, use this skill
