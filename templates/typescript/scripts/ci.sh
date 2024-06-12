#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[ci] %s\n' "$*"
}

log "Running TypeScript CI checks..."
echo ""

log "0. Validating package.json..."
if grep -q '"scripts"' package.json; then
  echo "❌ Error: package.json should not have a 'scripts' section"
  echo "   Use justfile for task automation instead"
  exit 1
fi

log "1. Installing dependencies..."
bun install

log "2. Type checking..."
tsc --noEmit

log "3. Checking code format..."
biome format .

log "4. Running linter..."
biome check .

log "5. Running tests..."
bun test

echo ""
log "✅ All CI checks passed!"
