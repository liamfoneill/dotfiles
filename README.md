# dotfiles

Personal macOS dotfiles for keeping work and personal machines in sync. Uses [GNU Stow](https://www.gnu.org/software/stow/) for symlink management and a single idempotent install script with profile-based configuration.

## Quick Start

```bash
# Clone the repo (wherever you keep repositories)
git clone https://github.com/liamfoneill/dotfiles.git
cd dotfiles

# Personal machine
./install.sh --profile personal

# Work machine (includes Stripe tooling, Cursor, work .zshrc, etc.)
./install.sh --profile work
```

That's it. The script handles Homebrew, symlinks, fonts, macOS preferences, and prints a summary report when done.

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
├── scripts/
│   └── helpers.sh             # Shared logging and utility functions
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
```

The install script creates this file from a template on first run. Edit it with your personal or work identity.

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

Before overwriting any existing file (including symlinks), the install script creates a timestamped backup in `~/.dotfiles-backup/`. These are excluded from the repo via `.gitignore`.

## Stripe CLI Setup

The repo includes a template at `stow/stripe/.config/stripe/config.toml.example` with placeholder values. The install script copies this template only if no config exists yet. After install, authenticate each project:

```bash
stripe login
```

Real API keys are never committed to the repo (`.gitignore` excludes `config.toml`).

## Raycast

Raycast doesn't support file-based config. See [`raycast/README.md`](raycast/README.md) for manual export/import instructions.
