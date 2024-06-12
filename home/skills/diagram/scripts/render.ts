#!/usr/bin/env -S bun --install=fallback
/**
 * Render a Mermaid diagram to ASCII (terminal) or SVG (file).
 *
 * Usage:
 *   render.ts <mermaid-file-or-string> [options]
 *
 * Options:
 *   --svg <output.svg>    Write SVG to file (default: ASCII to stdout)
 *   --theme <name>        Use a built-in theme (default: zinc-dark for SVG)
 *   --ascii               Force ASCII mode (no unicode box-drawing)
 *   --transparent         Transparent SVG background
 *   --open                Open SVG in browser after rendering
 *
 * Examples:
 *   render.ts diagram.mmd                     # ASCII to stdout
 *   render.ts diagram.mmd --svg out.svg       # SVG to file
 *   render.ts "graph LR; A --> B"             # Inline mermaid string
 *   render.ts diagram.mmd --svg out.svg --theme tokyo-night --open
 */
import { renderMermaid, renderMermaidAscii, THEMES } from "beautiful-mermaid";
import { existsSync } from "fs";

const args = process.argv.slice(2);

function usage() {
  console.error(`Usage: render.ts <mermaid-file-or-string> [--svg <output.svg>] [--theme <name>] [--ascii] [--transparent] [--open]

Available themes: ${Object.keys(THEMES).join(", ")}`);
  process.exit(1);
}

if (args.length === 0) usage();

// Parse args
let input = "";
let svgOutput = "";
let themeName = "";
let useAscii = false;
let transparent = false;
let openAfter = false;

for (let i = 0; i < args.length; i++) {
  const arg = args[i]!;
  if (arg === "--svg") {
    svgOutput = args[++i] || "";
  } else if (arg === "--theme") {
    themeName = args[++i] || "";
  } else if (arg === "--ascii") {
    useAscii = true;
  } else if (arg === "--transparent") {
    transparent = true;
  } else if (arg === "--open") {
    openAfter = true;
  } else if (arg === "--help" || arg === "-h") {
    usage();
  } else if (!input) {
    input = arg;
  }
}

if (!input) usage();

// Resolve input: file path or inline string
let mermaidSource: string;
if (existsSync(input)) {
  mermaidSource = await Bun.file(input).text();
} else {
  mermaidSource = input;
}

mermaidSource = mermaidSource.trim();

// If the source looks like a single-line semicolon-separated diagram, convert to newlines
// (the ASCII parser requires newline-separated syntax)
if (!mermaidSource.includes("\n") && mermaidSource.includes(";")) {
  mermaidSource = mermaidSource.replace(/;\s*/g, "\n");
}

if (svgOutput) {
  // SVG mode
  const theme = themeName ? THEMES[themeName] : THEMES["zinc-dark"];
  if (themeName && !theme) {
    console.error(`Unknown theme: ${themeName}\nAvailable: ${Object.keys(THEMES).join(", ")}`);
    process.exit(1);
  }
  const options = { ...theme, transparent };
  const svg = await renderMermaid(mermaidSource, options);
  await Bun.write(svgOutput, svg);
  console.error(`SVG written to ${svgOutput} (theme: ${themeName || "zinc-dark"})`);

  if (openAfter) {
    const { spawn } = await import("child_process");
    const cmd = process.platform === "darwin" ? "open" : "xdg-open";
    spawn(cmd, [svgOutput], { detached: true, stdio: "ignore" }).unref();
  }
} else {
  // ASCII mode
  const output = renderMermaidAscii(mermaidSource, { useAscii });
  console.log(output);
}
