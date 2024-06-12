In order to install NixOS on a new host from my Mac, see the `hetzner` configuration for reference.

```
$ nix run github:nix-community/nixos-anywhere -- --flake .#<output> root@<ip> --build-on-remote -L
```

Yabai & SKHD

yabai --restart-service
yabai --start-service

## Color scheme switcher

`bin/colorscheme` manages per-theme snippets in `themes/<name>/` and symlinks the active selection into `~/.local/state/colorscheme`. Ghostty, tmux, and Helix read from those links so the repo stays clean.
- `bin/colorscheme` or `bin/colorscheme menu --live` opens an fzf picker (live mode reapplies while you move; canceling restores the original theme). Every cursor move re-sources tmux, sends `:colorscheme-reload` to each Helix pane in tmux, and (unless `COLORSCHEME_RELOAD_GHOSTTY=0`) triggers Ghostty’s “Reload Configuration” menu through AppleScript—grant Accessibility/Automation permissions once and it’s hands-free.
- `bin/colorscheme list` shows the available schemes (`nord`, `tokyonight`).
- `bin/colorscheme apply <name>` switches without launching the picker.
- `bin/colorscheme current` prints the active scheme, falling back to `nord` when nothing has been selected.

To add a theme, drop `ghostty.conf`, `tmux.conf`, and `helix.toml` under `themes/<name>/`. All symlinks point back into the repo, so if you move the repo you'll need to re-run `bin/colorscheme apply <name>` to refresh the links.
# Test deployment trigger
# Test runner factory deployment
# Trigger deployment test
