# Dotfiles Repository — Agent Instructions

This is a macOS dotfiles repository that keeps a work machine (Stripe) and personal machine in sync. Read this before making any changes.

## Architecture

- **Symlinks via GNU Stow**: configs in `stow/<module>/` are symlinked to `$HOME` by `stow -d stow -t ~ <module>`. The directory structure inside each stow package mirrors the target layout relative to `$HOME`.
- **Profile system**: every install requires `--profile work` or `--profile personal`. There is no default — omitting `--profile` is an error.
- **Three-way split**: many configs have a common base (always installed), a work overlay, and a personal overlay. When adding new items, put them in the right tier.

## Key Files

| File | Purpose |
|------|---------|
| `install.sh` | Main idempotent installer. Always use `--profile work` or `--profile personal`. |
| `update.sh` | Convenience wrapper: `git pull` then `install.sh`. Auto-detects profile. |
| `uninstall.sh` | Removes symlinks, optionally restores backups (`--restore`). |
| `scripts/helpers.sh` | Shared logging, backup, and stow utilities. Sourced by other scripts — does NOT set shell options. |

## Directory Layout

```
homebrew/
├── Brewfile              # Common packages (always)
├── work/Brewfile         # Work-only (Stripe taps, build deps)
└── personal/Brewfile     # Personal-only (user fills in)

stow/
├── zsh/.zshrc            # Shared shell config
├── zsh/.zshrc.work       # Work profile overlay
├── zsh/.zshrc.personal   # Personal profile overlay
├── git/.gitconfig        # Shared git (includes ~/.gitconfig.local)
├── starship/...          # Starship prompt
├── ghostty/...           # Ghostty terminal
├── yazi/...              # Yazi file manager
├── hammerspoon/...       # Hammerspoon automation
├── vscode/...            # VS Code keybindings + settings
├── cursor/...            # Cursor keybindings + settings (work-only)
├── stripe/...            # Stripe CLI config template
└── rectangle/...         # Rectangle window manager plist
```

## Shell Script Conventions

- Scripts use `#!/usr/bin/env bash` and `set -uo pipefail` (but NOT `set -e` at top level — modules run in subshells with `set -e` and use `&& track_module ... || track_module ...`).
- `scripts/helpers.sh` is sourced, never executed directly. It must NOT set shell options.
- Logging uses `info`, `success`, `warn`, `error`, `step`, `header` functions from `helpers.sh`. All produce colored output.
- Every module follows this pattern:

```bash
next_step "Module Name"
if should_skip "module"; then
    warn "Skipped (--skip module)"
    track_module "Module" "skipped"
else
    (
        set -e
        # ... do work ...
    ) && track_module "Module" "installed" \
      || track_module "Module" "failed"
fi
```

- Use `dry_run "description"` to gate side effects. It returns 0 (true) in dry-run mode, printing the description.
- Use `backup_file "$path"` before overwriting any existing file.
- Use `stow_module "package"` / `unstow_module "package"` instead of calling stow directly.
- `PROFILE` is exported globally. Check it with `[[ "$PROFILE" == "work" ]]` etc.

## Profile-Aware Logic

When a module should only run for one profile:

```bash
elif [[ "$PROFILE" != "work" ]]; then
    info "Skipped (work-only — use --profile work to install)"
    track_module "Module" "skipped"
```

When a Brewfile or config has profile variants, install common first, then the profile-specific one:

```bash
brew bundle --file="${brewdir}/Brewfile" --no-lock
brew bundle --file="${brewdir}/${PROFILE}/Brewfile" --no-lock
```

## Brewfiles

Each `Brewfile` is a standard Homebrew Bundle file (Ruby DSL). All files must be named exactly `Brewfile` (not `Brewfile.work` etc.) so that VS Code extensions and linters recognise them. The subdirectory provides the context.

## Secrets

Never commit real credentials. Sensitive files are in `.gitignore`:
- `stow/stripe/.config/stripe/config.toml`
- `stow/git/.gitconfig.local`

Templates with `.example` suffix are committed instead.

## Testing Changes

```bash
# Dry run (no changes)
./install.sh --profile work --dry-run

# Lint
shellcheck install.sh uninstall.sh update.sh scripts/helpers.sh macos/defaults.sh hooks/post-merge --severity=warning --exclude=SC2059
```

## Common Tasks

- **Add a new stow module**: create `stow/<name>/` mirroring the `$HOME` layout, add a module block in `install.sh`, increment `TOTAL_MODULES`, add unstow in `uninstall.sh`.
- **Add a Homebrew package**: append to the appropriate `homebrew/Brewfile`, `homebrew/work/Brewfile`, or `homebrew/personal/Brewfile`.
- **Add a new profile-specific zsh config**: edit `stow/zsh/.zshrc.work` or `stow/zsh/.zshrc.personal`.
