---
name: init-ci
description: Initialize CI/CD for a project using Nix + GitHub Actions + Blacksmith runners. Use when setting up continuous integration, adding pre-merge checks, post-merge deploys, or nightly jobs. Creates GitHub Actions workflows that delegate to justfile recipes running inside nix develop.
---

# Initialize CI

Set up Nix-based CI/CD with GitHub Actions and Blacksmith runners.

## Philosophy

- **Minimal logic in YAML** - Workflows just call `nix develop -c just <recipe>`
- **Justfile is source of truth** - All CI logic lives in justfile recipes
- **Reproducible everywhere** - Same nix environment locally and in CI
- **Efficient caching** - Blacksmith sticky disk caches /nix between runs

## Quick Start

1. Ensure project has `flake.nix` with a devShell
2. Add justfile recipes: `pre-merge`, `post-merge`, `nightly` (as needed)
3. Create `.github/workflows/` with appropriate workflow files

## Justfile Recipes

Add to project's `justfile`:

```just
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# Check for nix shell
[private]
nix-check:
    @test -n "$IN_NIX_SHELL" || (echo "Run 'nix develop' first" && exit 1)

# Pre-merge checks (lint, test, build)
pre-merge: nix-check
    # Add your checks here
    just lint
    just test
    @echo "All checks passed!"

# Post-merge deploy (optional)
post-merge: nix-check
    # Add deploy logic here
    ./scripts/deploy.sh

# Nightly tasks (optional)
nightly: nix-check
    # Add nightly tasks here
    just test-e2e
```

## GitHub Actions Workflows

### Pre-merge (PR checks)

`.github/workflows/pre-merge.yml`:

```yaml
name: pre-merge

on:
  pull_request:
    branches: [main, master]
  workflow_dispatch:

jobs:
  check:
    runs-on: blacksmith-16vcpu-ubuntu-2404
    steps:
      - uses: actions/checkout@v4
      - uses: useblacksmith/stickydisk@v1
        with:
          key: ${{ github.repository }}-nix-${{ runner.os }}
          path: /nix
      - run: |
          if [ -d /nix ] && [ "$(stat -c %u /nix)" != "$(id -u)" ]; then
            sudo chown -R $(id -u):$(id -g) /nix
          fi
      - uses: nixbuild/nix-quick-install-action@v30
      - run: nix develop -c just pre-merge
```

### Post-merge (deploy on push to main)

`.github/workflows/post-merge.yml`:

```yaml
name: post-merge

on:
  push:
    branches: [main, master]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: blacksmith-16vcpu-ubuntu-2404
    steps:
      - uses: actions/checkout@v4
      - uses: useblacksmith/stickydisk@v1
        with:
          key: ${{ github.repository }}-nix-${{ runner.os }}
          path: /nix
      - run: |
          if [ -d /nix ] && [ "$(stat -c %u /nix)" != "$(id -u)" ]; then
            sudo chown -R $(id -u):$(id -g) /nix
          fi
      - uses: nixbuild/nix-quick-install-action@v30
      - uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.DEPLOY_SSH_KEY }}
      - run: nix develop -c just post-merge
        env:
          DEPLOY_HOST: ${{ secrets.DEPLOY_HOST }}
```

### Nightly

`.github/workflows/nightly.yml`:

```yaml
name: nightly

on:
  schedule:
    - cron: '0 8 * * *'  # 8am UTC daily
  workflow_dispatch:

jobs:
  nightly:
    runs-on: blacksmith-16vcpu-ubuntu-2404
    steps:
      - uses: actions/checkout@v4
      - uses: useblacksmith/stickydisk@v1
        with:
          key: ${{ github.repository }}-nix-${{ runner.os }}
          path: /nix
      - run: |
          if [ -d /nix ] && [ "$(stat -c %u /nix)" != "$(id -u)" ]; then
            sudo chown -R $(id -u):$(id -g) /nix
          fi
      - uses: nixbuild/nix-quick-install-action@v30
      - run: nix develop -c just nightly
```

## Flake Requirements

Ensure `flake.nix` exports a devShell with `just` and sets `IN_NIX_SHELL`:

```nix
devShells = forAllSystems ({ pkgs, ... }: {
  default = pkgs.mkShell {
    packages = with pkgs; [
      just
      # ... other deps
    ];
    shellHook = ''
      export IN_NIX_SHELL=1
    '';
  };
});
```

## Blacksmith Runner Sizes

Available runners:
- `blacksmith-2vcpu-ubuntu-2404` - Small tasks
- `blacksmith-4vcpu-ubuntu-2404` - Default
- `blacksmith-8vcpu-ubuntu-2404` - Medium builds
- `blacksmith-16vcpu-ubuntu-2404` - Large builds, Nix (recommended for most Nix projects)
- `blacksmith-32vcpu-ubuntu-2404` - Heavy compilation

**When setting up CI, recommend a runner size based on project complexity but always ask the user to confirm before using it.** For most Nix projects, `blacksmith-16vcpu-ubuntu-2404` is a good default due to Nix build parallelism.
