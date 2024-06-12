# Justin's Blog

A minimal Astro blog with a brutalist aesthetic inspired by [Collapse OS](https://collapseos.org).

## Development

The blog directory has a `.envrc` that automatically loads the Nix dev shell with Bun.

Run dev server (installs deps and opens browser):

```bash
just dev
```

Build for production:

```bash
just build
```

Preview production build:

```bash
just preview
```

## Deployment

The blog is configured to be served from `/var/www/static/blog` on the Hetzner server.

Build and deploy:

```bash
bun run build
rsync -av dist/ root@server:/var/www/static/blog/
```

## Design Philosophy

- Minimal HTML/CSS (no JavaScript)
- Monospace fonts
- High contrast
- Fast load times
- Accessible by default
