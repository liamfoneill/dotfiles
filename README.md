# dotfiles

Personal macOS dotfiles for keeping work and personal machines in sync. Uses [GNU Stow](https://www.gnu.org/software/stow/) for symlink management and a single idempotent install script with profile-based configuration.

## Brand New Mac

On a factory-fresh Mac (no git, no Homebrew), run this single command from Terminal:

```bash
# Personal machine
bash <(curl -fsSL https://raw.githubusercontent.com/liamfoneill/dotfiles/main/scripts/bootstrap.sh) --profile personal

# Work machine
bash <(curl -fsSL https://raw.githubusercontent.com/liamfoneill/dotfiles/main/scripts/bootstrap.sh) --profile work
```

This installs Xcode Command Line Tools, Homebrew, clones the repo to `~/dotfiles`, and runs the full installer. No prerequisites needed.

### After install

A few things need manual setup after the first run:

1. **1Password** -- launch and sign in, then enable SSH agent (Settings > Developer > SSH Agent)
2. **Git identity** -- edit `~/.gitconfig.local` with your name, email, and signing key
3. **Git signing** -- once 1Password is set up, change `gpgsign = false` to `gpgsign = true` in `~/.gitconfig.local`
4. **Stripe CLI** (work) -- run `stripe login` to authenticate
5. **Raycast** -- import config manually (see `raycast/README.md`)

## Setting Up an Existing Mac

If your machine already has most things installed (Homebrew, apps, configs), follow this sequence to adopt the dotfiles without losing anything.

### 1. Clone and preview

```bash
git clone https://github.com/liamfoneill/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --profile personal --dry-run
```

The dry run shows exactly what would happen without touching anything. Review the output.

### 2. Review your existing configs

The installer will **back up and replace** your existing `.zshrc`, `.gitconfig`, and other dotfiles. Before running for real, check what you have and what you might lose:

```bash
# See which shell config files you currently have
ls -la ~/.zshrc ~/.zprofile ~/.zshenv ~/.bash_profile 2>/dev/null

# If you have an existing .zshrc, compare it with the repo version
# (unified diff: lines with - are yours, lines with + are the repo's)
diff -u "$HOME/.zshrc" "$HOME/dotfiles/stow/zsh/.zshrc" 2>/dev/null

# Same for gitconfig
diff -u "$HOME/.gitconfig" "$HOME/dotfiles/stow/git/.gitconfig" 2>/dev/null
```

If you don't have a `.zshrc` yet (common on fresh-ish Macs where config lives in `.zprofile`), there's nothing to lose -- the installer will create one. Review your `.zprofile` for anything you want to keep.

Anything personal you want to keep should go in:
- `stow/zsh/.zshrc.personal` -- personal shell config (sourced by the shared `.zshrc`)
- `~/.zshrc.local` -- machine-specific overrides (not in the repo, never synced)
- `~/.gitconfig.local` -- git identity and signing (created from template on first run)

### 3. Populate your personal Brewfile

The common Brewfile covers packages used on both machines. Work-specific packages are already set. But `homebrew/personal/Brewfile` is empty -- you need to fill it with anything that's personal-only.

Dump what you currently have installed:

```bash
brew bundle dump --file=/tmp/personal-dump --force --describe
```

Compare it with the common Brewfile to find what's different:

```bash
# See what's on your machine but not in the common Brewfile
# (unified diff: - lines are in the repo, + lines are on your machine only)
diff -u <(grep -E '^(brew|cask|tap)' homebrew/Brewfile | sort) \
        <(grep -E '^(brew|cask|tap)' /tmp/personal-dump | sort)
```

Add personal-only packages (apps blocked by corporate policy, personal tools, games, etc.) to `homebrew/personal/Brewfile`:

```ruby
# homebrew/personal/Brewfile
cask "istat-menus"
cask "steam"
cask "vlc"
```

The app inventory script can also help identify what's installed:

```bash
./scripts/app-inventory.sh
```

### 4. Run the installer

```bash
./install.sh --profile personal
```

Everything is idempotent -- already-installed Homebrew packages are skipped, identical fonts are skipped, and `defaults write` with the same value is a no-op. Your original configs are saved to `~/.dotfiles-backup/<timestamp>/`.

### 5. Post-install

1. **1Password** -- launch and sign in, enable SSH agent (Settings > Developer > SSH Agent)
2. **Git identity** -- edit `~/.gitconfig.local` with your name, email, and signing key
3. **Git signing** -- change `gpgsign = false` to `gpgsign = true` in `~/.gitconfig.local`
4. **Rust** -- run `rustup-init` (Homebrew installs `rustup` but the toolchain needs init)
5. **Raycast** -- import config manually (see `raycast/README.md`)
6. **Finder sidebar** -- create `~/.dotfiles-sidebar` for personal sidebar items (see [Finder Sidebar](#finder-sidebar))
7. **Commit your Brewfile** -- push your personal Brewfile back to the repo

```bash
cd ~/dotfiles
git add homebrew/personal/Brewfile
git commit -m "Add personal Brewfile"
git push
```

### Rolling back

If something breaks, restore your original configs:

```bash
./scripts/rollback.sh --latest
# Or fully uninstall and restore:
./uninstall.sh --restore
```

## Quick Start

If you already have git and Homebrew:

```bash
git clone https://github.com/liamfoneill/dotfiles.git
cd dotfiles

./install.sh --profile personal     # Personal machine
./install.sh --profile work         # Work machine
```

The script handles Homebrew, symlinks, fonts, macOS preferences, and prints a summary report when done.

## Profiles

Every machine runs as either `work` or `personal`. The `--profile` flag controls which profile-specific packages, configs, and tools are installed alongside the common base.

| | Common (always) | Work only | Personal only |
|---|---|---|---|
| **Brewfile** | `homebrew/Brewfile` | `homebrew/work/Brewfile` | `homebrew/personal/Brewfile` |
| **Zsh** | `.zshrc` | `.zshrc.work` | `.zshrc.personal` |
| **Cursor** | -- | keybindings + settings | -- |
| **Everything else** | All modules | All modules | All modules |

## What's Synced

| Module | Method | Updates on `git pull`? |
|--------|--------|----------------------|
| **Zsh** (.zshrc + profile) | Symlink via Stow | Yes (instant) |
| **Git** (.gitconfig) | Symlink via Stow | Yes (instant) |
| **Starship** (starship.toml) | Symlink via Stow | Yes (instant) |
| **Ghostty** (terminal config) | Symlink via Stow | Yes (instant) |
| **Yazi** (file manager config) | Symlink via Stow | Yes (instant) |
| **Hammerspoon** (init.lua) | Symlink via Stow | Yes (instant) |
| **VS Code** (keybindings + settings) | Symlink via Stow | Yes (instant) |
| **Cursor** (keybindings + settings) | Symlink via Stow (work only) | Yes (instant) |
| **Homebrew** (Brewfile) | `brew bundle` | No (re-run install) |
| **Rectangle** (window manager) | Plist copy | No (re-run install) |
| **Fonts** (Nerd Fonts) | File copy | No (re-run install) |
| **macOS** (Finder, Dock, etc.) | `defaults write` | No (re-run install) |
| **Stripe CLI** (config template) | File copy (template) | No (manual) |
| **Raycast** | Manual export/import | No (manual) |
| **Auto-Sync** | launchd agent (hourly) | Automatic (git pull) |

## What's NOT Synced

- **SSH keys** -- handled by 1Password
- **VS Code extensions** -- machine-specific
- **Apple Notes, Reminders, Calendar** -- synced via iCloud/Google natively
- **iCloud / Google Drive** -- machine-specific cloud storage

## Repository Structure

```
dotfiles/
├── install.sh                 # Main installer (idempotent)
├── update.sh                  # Pull + re-install (auto-detects profile)
├── uninstall.sh               # Remove symlinks, optionally restore backups
│
├── homebrew/                  # Brewfiles (each named Brewfile for tooling)
│   ├── Brewfile               # Common packages (always installed)
│   ├── work/
│   │   └── Brewfile           # Work-only (Stripe taps, build tools)
│   └── personal/
│       └── Brewfile           # Personal-only (add your own)
│
├── stow/                      # Symlinked configs (managed by GNU Stow)
│   ├── zsh/
│   │   ├── .zshrc             # Shared shell config
│   │   ├── .zshrc.work        # Work profile (Stripe Chef init, etc.)
│   │   └── .zshrc.personal    # Personal profile (your customisations)
│   ├── git/
│   │   ├── .gitconfig         # Shared git settings (delta, signing, LFS)
│   │   └── .gitconfig.local.example
│   ├── starship/
│   │   └── .config/starship.toml
│   ├── ghostty/
│   │   └── .config/ghostty/config
│   ├── yazi/
│   │   └── .config/yazi/{yazi,keymap,previewers}.toml
│   ├── hammerspoon/
│   │   └── .hammerspoon/init.lua
│   ├── vscode/
│   │   └── Library/Application Support/Code/User/{keybindings,settings}.json
│   ├── cursor/
│   │   └── Library/Application Support/Cursor/User/{keybindings,settings}.json
│   ├── stripe/
│   │   └── .config/stripe/config.toml.example
│   └── rectangle/
│       └── Library/Preferences/com.knollsoft.Rectangle.plist
│
├── fonts/                     # Nerd Fonts (FiraCode, Hack, CaskaydiaCove)
├── hooks/
│   └── post-merge             # Reminds to re-run when Brewfile/fonts change
├── macos/
│   └── defaults.sh            # Finder, Dock, keyboard, sidebar preferences
├── raycast/
│   └── README.md              # Manual import/export instructions
├── inventory/                 # App snapshots per machine (for diffing)
│   ├── apps-work.txt
│   └── apps-personal.txt
├── scripts/
│   ├── bootstrap.sh           # One-liner setup for a brand new Mac
│   ├── helpers.sh             # Shared logging and utility functions
│   ├── app-inventory.sh       # Scan /Applications and write tagged manifest
│   ├── auto-sync.sh           # Hourly git pull + snapshot (runs via launchd)
│   ├── rollback.sh            # List/restore config snapshots
│   └── com.dotfiles.sync.plist  # launchd agent template
└── .github/
    └── workflows/lint.yml     # CI: shellcheck + Brewfile validation
```

## Usage

### Install

```bash
./install.sh --profile personal     # Personal machine
./install.sh --profile work         # Work machine
```

### Update (pull + re-install)

```bash
./update.sh                         # Auto-detects profile
./update.sh --skip fonts            # Pass any install.sh flags
```

### Skip Specific Modules

```bash
./install.sh --profile personal --skip fonts --skip macos
./install.sh --profile work --skip homebrew
```

### Dry Run

Preview what will happen without making changes:

```bash
./install.sh --profile work --dry-run
```

### Available Modules

| Module | Flag | Description |
|--------|------|-------------|
| `homebrew` | `--skip homebrew` | Homebrew packages (common + profile) |
| `zsh` | `--skip zsh` | Zsh configuration + profile overrides |
| `git` | `--skip git` | Git configuration (.gitconfig) |
| `starship` | `--skip starship` | Starship prompt theme |
| `ghostty` | `--skip ghostty` | Ghostty terminal settings |
| `yazi` | `--skip yazi` | Yazi file manager config |
| `hammerspoon` | `--skip hammerspoon` | Hammerspoon automation |
| `vscode` | `--skip vscode` | VS Code keybindings + settings |
| `cursor` | `--skip cursor` | Cursor keybindings + settings (work only) |
| `stripe` | `--skip stripe` | Stripe CLI config template |
| `rectangle` | `--skip rectangle` | Rectangle window manager |
| `fonts` | `--skip fonts` | Nerd Fonts (FiraCode, Hack, CaskaydiaCove) |
| `macos` | `--skip macos` | macOS Finder/Dock/keyboard prefs |
| `raycast` | `--skip raycast` | Raycast import reminder |
| `auto-sync` | `--skip auto-sync` | Hourly launchd sync with backup + rollback |

## How Syncing Works

### Symlinked Configs (instant updates)

For zsh, git, starship, ghostty, yazi, hammerspoon, and VS Code/Cursor, the install script creates symlinks using GNU Stow. The actual files live in this repo, so after a `git pull`, changes are immediately active:

```
~/.zshrc                -> <repo>/stow/zsh/.zshrc
~/.gitconfig            -> <repo>/stow/git/.gitconfig
~/.config/starship.toml -> <repo>/stow/starship/.config/starship.toml
```

A post-merge git hook will remind you to re-run `./install.sh` when non-symlinked files (Brewfile, fonts, macOS defaults) change.

### Copied Configs (need re-run)

Fonts, Rectangle preferences, and macOS defaults are copied/applied rather than symlinked. After pulling changes, re-run:

```bash
./update.sh
```

## Day-to-Day Workflow

### Pulling Changes

```bash
cd <repo>
git pull
# Or just:
./update.sh
```

Symlinked configs update instantly. The post-merge hook will tell you if a re-run is needed.

### Making Changes

Edit the files in this repo directly (or edit the symlinked files -- they're the same thing):

```bash
# These are equivalent:
vim <repo>/stow/ghostty/.config/ghostty/config
vim ~/.config/ghostty/config  # This is a symlink to the above
```

Then commit and push:

```bash
cd <repo>
git add -A
git commit -m "Update ghostty font size"
git push
```

### Adding a New Homebrew Package

```bash
brew install <package>

# Add to the appropriate Brewfile:
echo 'brew "<package>"' >> homebrew/Brewfile            # common
echo 'brew "<package>"' >> homebrew/work/Brewfile       # work-only
echo 'brew "<package>"' >> homebrew/personal/Brewfile   # personal-only

git add -A && git commit -m "Add <package>" && git push
```

### Updating Fonts

Drop `.ttf` or `.otf` files into the `fonts/` directory and re-run install.

## Git Configuration

The repo ships a shared `.gitconfig` with common settings (delta pager, 1Password SSH signing, LFS, merge conflict style). Machine-specific identity goes in `~/.gitconfig.local`:

```gitconfig
[user]
    name = Liam O'Neill
    email = liamfoneill@users.noreply.github.com
    signingkey = ssh-ed25519 YOUR_KEY_HERE
[commit]
    gpgsign = true
```

The install script creates this file from a template on first run (with signing disabled by default so git works immediately). Once 1Password is installed and your SSH key is configured, set `gpgsign = true` in `~/.gitconfig.local`.

## Finder Sidebar

Shared sidebar items (Home, Desktop, Downloads, etc.) are set automatically. Machine-specific items are configured via `~/.dotfiles-sidebar` (not in the repo):

```
# Work example
GitHub|~/stripe/Github
GitHub Enterprise|~/stripe/Github-Enterprise
Google Drive|~/Library/CloudStorage/GoogleDrive

# Personal example
GitHub|~/Developer/Github
iCloud|~/Library/Mobile Documents/com~apple~CloudDocs
```

## Uninstalling

```bash
# Remove symlinks only
./uninstall.sh

# Remove symlinks and restore backed-up files
./uninstall.sh --restore
```

Note: Homebrew packages, fonts, and macOS defaults are not reverted by uninstall.

## Backups

Backups are stored in `~/.dotfiles-backup/` (excluded from the repo via `.gitignore`):

- **Install backups** (`~/.dotfiles-backup/<timestamp>/`) -- created by `install.sh` before overwriting any existing file
- **Auto-sync snapshots** (`~/.dotfiles-backup/auto-sync/<timestamp>/`) -- created by the hourly auto-sync before each `git pull`

Use `./scripts/rollback.sh` to list all snapshots and `./scripts/rollback.sh --latest` to restore.

## Stripe CLI Setup

The repo includes a template at `stow/stripe/.config/stripe/config.toml.example` with placeholder values. The install script copies this template only if no config exists yet. After install, authenticate each project:

```bash
stripe login
```

Real API keys are never committed to the repo (`.gitignore` excludes `config.toml`).

## App Inventory

Not everything can be managed by Homebrew (Mac App Store apps, corporate tools, direct downloads). The inventory script snapshots what's installed on each machine so you can compare and decide what to install manually.

```bash
# Snapshot this machine
./scripts/app-inventory.sh

# Compare machines (once both have been snapshotted and committed)
diff -u inventory/apps-work.txt inventory/apps-personal.txt
```

Each app is tagged by install source: `[brew]`, `[system]`, `[corp]`, or `[manual]`. The script is read-only -- it lists apps but installs nothing.

## Auto-Sync

A launchd agent runs `git pull` every hour to keep symlinked configs up to date automatically. Before each pull, it snapshots all symlinked config files so you can roll back if a bad commit breaks something.

### What it does

1. Checks for upstream changes (skips if already up to date)
2. Snapshots current config files to `~/.dotfiles-backup/auto-sync/<timestamp>/`
3. Runs `git pull --ff-only`
4. If non-symlinked files changed (Brewfile, fonts, macOS defaults), sends a macOS notification to re-run `install.sh`
5. Prunes old snapshots (keeps last 10)
6. Logs everything to `~/.local/share/dotfiles/sync.log`

### Rollback

If a pulled change breaks your config:

```bash
# List available snapshots
./scripts/rollback.sh

# Restore the most recent snapshot
./scripts/rollback.sh --latest

# Restore a specific snapshot
./scripts/rollback.sh 20260223_143000
```

Rollback writes files back into the repo (not just `$HOME`), so the fix persists across future pulls until overwritten by a new commit.

### Managing the agent

```bash
# Disable auto-sync
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.dotfiles.sync.plist

# Re-enable auto-sync
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.dotfiles.sync.plist

# Run manually
./scripts/auto-sync.sh

# Check the log
tail -f ~/.local/share/dotfiles/sync.log

# Skip during install (don't install the launchd agent)
./install.sh --profile work --skip auto-sync
```

## Raycast

Raycast doesn't support file-based config. See [`raycast/README.md`](raycast/README.md) for manual export/import instructions.
