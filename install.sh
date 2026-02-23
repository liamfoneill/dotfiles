#!/usr/bin/env bash
#
# Dotfiles installer
#
# Usage: ./install.sh [OPTIONS]
#
# Options:
#   --profile <p>  Set machine profile: work or personal
#   --skip <mod>   Skip a module (repeatable)
#   --dry-run      Show what would be done without making changes
#   --help         Show this help message

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "${SCRIPT_DIR}/scripts/helpers.sh"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
PROFILE=""
DRY_RUN=false
declare -A SKIP_MODULES=()
TOTAL_MODULES=14

usage() {
    cat <<'EOF'

  Dotfiles Installer

  Usage: ./install.sh [OPTIONS]

  Options:
    --profile <p>  Set machine profile: work or personal
    --skip <mod>   Skip a module (can be repeated)
    --dry-run      Show what would be done without making changes
    --help         Show this help message

  Profiles:
    work           Includes work Brewfile, .zshrc.work, Cursor config
    personal       Includes personal Brewfile, .zshrc.personal

  Modules:
    homebrew    Homebrew packages (common + profile-specific)
    zsh         Zsh configuration (.zshrc + profile overrides)
    git         Git configuration (.gitconfig)
    starship    Starship prompt (starship.toml)
    ghostty     Ghostty terminal (config)
    yazi        Yazi file manager (keymap, previewers, settings)
    hammerspoon Hammerspoon automation (init.lua)
    vscode      VS Code keybindings + settings
    cursor      Cursor keybindings + settings (work profile only)
    stripe      Stripe CLI config template
    rectangle   Rectangle window manager
    fonts       Nerd Fonts (FiraCode, Hack, CaskaydiaCove)
    macos       macOS Finder & system preferences
    raycast     Raycast (manual import reminder)

EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            if [[ -z "${2:-}" ]]; then
                error "--profile requires a value: work or personal"
                exit 1
            fi
            if [[ "$2" != "work" && "$2" != "personal" ]]; then
                error "Unknown profile: $2 (expected 'work' or 'personal')"
                exit 1
            fi
            PROFILE="$2"
            shift 2
            ;;
        --dry-run)  DRY_RUN=true; shift ;;
        --all)      shift ;;
        --skip)
            if [[ -z "${2:-}" ]]; then
                error "--skip requires a module name"
                exit 1
            fi
            SKIP_MODULES["$2"]=1
            shift 2
            ;;
        --help|-h)  usage; exit 0 ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$PROFILE" ]]; then
    error "No profile specified. Use --profile work or --profile personal"
    usage
    exit 1
fi

export DRY_RUN
export PROFILE

should_skip() {
    [[ -n "${SKIP_MODULES[${1}]:-}" ]]
}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
printf "\n"
printf "  ${BOLD}${CYAN}┌─────────────────────────────────────┐${RESET}\n"
printf "  ${BOLD}${CYAN}│          Dotfiles Installer         │${RESET}\n"
printf "  ${BOLD}${CYAN}└─────────────────────────────────────┘${RESET}\n"
printf "\n"
info "Dotfiles directory: ${DIM}${DOTFILES_DIR}${RESET}"
info "Profile: ${BOLD}${PROFILE}${RESET}"
info "Dry run: ${DRY_RUN}"
printf "\n"

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
header "Checking Prerequisites"

if ! is_macos; then
    error "This installer is designed for macOS only."
    exit 1
fi
success "Running on macOS"

if ! xcode-select -p >/dev/null 2>&1; then
    info "Installing Xcode Command Line Tools..."
    if ! dry_run "xcode-select --install"; then
        xcode-select --install
        info "Waiting for Xcode CLT installation to complete..."
        until xcode-select -p >/dev/null 2>&1; do sleep 5; done
    fi
fi
success "Xcode Command Line Tools"

if ! command -v brew >/dev/null 2>&1; then
    info "Installing Homebrew..."
    if ! dry_run "Install Homebrew"; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi
success "Homebrew $(brew --version 2>/dev/null | head -1 | awk '{print $2}' || echo '')"

if ! command -v stow >/dev/null 2>&1; then
    info "Installing GNU Stow..."
    if [[ "$DRY_RUN" == "true" ]]; then
        info "${DIM}[dry-run]${RESET} brew install stow"
    else
        brew install stow
    fi
fi
if command -v stow >/dev/null 2>&1; then
    success "GNU Stow"
else
    if [[ "$DRY_RUN" == "true" ]]; then
        success "GNU Stow ${DIM}(would be installed)${RESET}"
    else
        error "GNU Stow installation failed"
        exit 1
    fi
fi

# Install git hooks
hook_src="${DOTFILES_DIR}/hooks/post-merge"
hook_dst="${DOTFILES_DIR}/.git/hooks/post-merge"
if [[ -f "$hook_src" && -d "${DOTFILES_DIR}/.git/hooks" ]]; then
    if ! dry_run "Install post-merge hook"; then
        cp "$hook_src" "$hook_dst"
        chmod +x "$hook_dst"
    fi
    success "Post-merge git hook"
fi

# ---------------------------------------------------------------------------
# Module counter
# ---------------------------------------------------------------------------
MODULE_NUM=0
next_step() {
    ((MODULE_NUM++))
    step "$MODULE_NUM" "$TOTAL_MODULES" "$1"
}

# ===== MODULE 1: Homebrew ====================================================
next_step "Homebrew Packages"

if should_skip "homebrew"; then
    warn "Skipped (--skip homebrew)"
    track_module "Homebrew" "skipped"
else
    (
        set -e
        brewdir="${DOTFILES_DIR}/homebrew"

        if ! dry_run "brew bundle --file=${brewdir}/Brewfile"; then
            brew bundle --file="${brewdir}/Brewfile"
            success "Common Brewfile installed"
        fi

        profile_brewfile="${brewdir}/${PROFILE}/Brewfile"
        if [[ -f "$profile_brewfile" ]]; then
            if ! dry_run "brew bundle --file=${profile_brewfile}"; then
                brew bundle --file="${profile_brewfile}"
                success "${PROFILE^} Brewfile installed"
            fi
        fi
    ) && track_module "Homebrew" "installed" \
      || track_module "Homebrew" "failed"
fi

# ===== MODULE 2: Zsh =========================================================
next_step "Zsh Configuration"

if should_skip "zsh"; then
    warn "Skipped (--skip zsh)"
    track_module "Zsh" "skipped"
else
    (
        set -e
        backup_file "${HOME}/.zshrc"

        if ! dry_run "stow zsh"; then
            stow_module "zsh"
            success "Linked .zshrc"
        fi

        # Symlink the profile-specific zshrc, remove the other
        if [[ "$PROFILE" == "work" ]]; then
            success "Work config (.zshrc.work) included via stow"
            if [[ -L "${HOME}/.zshrc.personal" ]]; then
                rm "${HOME}/.zshrc.personal"
                info "Removed .zshrc.personal symlink (work profile)"
            fi
        elif [[ "$PROFILE" == "personal" ]]; then
            success "Personal config (.zshrc.personal) included via stow"
            if [[ -L "${HOME}/.zshrc.work" ]]; then
                rm "${HOME}/.zshrc.work"
                info "Removed .zshrc.work symlink (personal profile)"
            fi
        fi
    ) && track_module "Zsh" "installed" \
      || track_module "Zsh" "failed"
fi

# ===== MODULE 3: Git ==========================================================
next_step "Git Configuration"

if should_skip "git"; then
    warn "Skipped (--skip git)"
    track_module "Git" "skipped"
else
    (
        set -e
        backup_file "${HOME}/.gitconfig"

        if ! dry_run "stow git"; then
            stow_module "git"
            success "Linked .gitconfig"
        fi

        gitconfig_local="${HOME}/.gitconfig.local"
        if [[ ! -f "$gitconfig_local" ]]; then
            cp "${STOW_DIR}/git/.gitconfig.local.example" "$gitconfig_local"
            warn "Created ${DIM}~/.gitconfig.local${RESET} from template — edit with your identity"
        else
            success ".gitconfig.local already exists"
        fi
    ) && track_module "Git" "installed" \
      || track_module "Git" "failed"
fi

# ===== MODULE 4: Starship ====================================================
next_step "Starship Prompt"

if should_skip "starship"; then
    warn "Skipped (--skip starship)"
    track_module "Starship" "skipped"
else
    (
        set -e
        backup_file "${HOME}/.config/starship.toml"
        mkdir -p "${HOME}/.config"

        if ! dry_run "stow starship"; then
            stow_module "starship"
            success "Linked starship.toml"
        fi
    ) && track_module "Starship" "installed" \
      || track_module "Starship" "failed"
fi

# ===== MODULE 4: Ghostty =====================================================
next_step "Ghostty Terminal"

if should_skip "ghostty"; then
    warn "Skipped (--skip ghostty)"
    track_module "Ghostty" "skipped"
else
    (
        set -e
        backup_file "${HOME}/.config/ghostty/config"
        mkdir -p "${HOME}/.config/ghostty"

        if ! dry_run "stow ghostty"; then
            stow_module "ghostty"
            success "Linked ghostty config"
        fi
    ) && track_module "Ghostty" "installed" \
      || track_module "Ghostty" "failed"
fi

# ===== MODULE 7: Yazi =========================================================
next_step "Yazi File Manager"

if should_skip "yazi"; then
    warn "Skipped (--skip yazi)"
    track_module "Yazi" "skipped"
else
    (
        set -e
        backup_file "${HOME}/.config/yazi/yazi.toml"
        backup_file "${HOME}/.config/yazi/keymap.toml"
        backup_file "${HOME}/.config/yazi/previewers.toml"
        mkdir -p "${HOME}/.config/yazi"

        if ! dry_run "stow yazi"; then
            stow_module "yazi"
            success "Linked yazi config"
        fi
    ) && track_module "Yazi" "installed" \
      || track_module "Yazi" "failed"
fi

# ===== MODULE 8: Hammerspoon ==================================================
next_step "Hammerspoon"

if should_skip "hammerspoon"; then
    warn "Skipped (--skip hammerspoon)"
    track_module "Hammerspoon" "skipped"
else
    (
        set -e
        backup_file "${HOME}/.hammerspoon/init.lua"
        mkdir -p "${HOME}/.hammerspoon"

        if ! dry_run "stow hammerspoon"; then
            stow_module "hammerspoon"
            success "Linked hammerspoon init.lua"
        fi
    ) && track_module "Hammerspoon" "installed" \
      || track_module "Hammerspoon" "failed"
fi

# ===== MODULE 9: VS Code =====================================================
next_step "VS Code Keybindings"

if should_skip "vscode"; then
    warn "Skipped (--skip vscode)"
    track_module "VS Code" "skipped"
else
    (
        set -e
        local_dir="${HOME}/Library/Application Support/Code/User"
        backup_file "${local_dir}/keybindings.json"
        backup_file "${local_dir}/settings.json"
        mkdir -p "${local_dir}"

        if ! dry_run "stow vscode"; then
            stow_module "vscode"
            success "Linked VS Code keybindings.json and settings.json"
        fi
    ) && track_module "VS Code" "installed" \
      || track_module "VS Code" "failed"
fi

# ===== MODULE 6: Cursor (work-only) ==========================================
next_step "Cursor (work-only)"

if should_skip "cursor"; then
    warn "Skipped (--skip cursor)"
    track_module "Cursor" "skipped"
elif [[ "$PROFILE" != "work" ]]; then
    info "Skipped (Cursor is work-only — use --profile work to install)"
    track_module "Cursor" "skipped"
else
    (
        set -e
        local_dir="${HOME}/Library/Application Support/Cursor/User"
        backup_file "${local_dir}/keybindings.json"
        backup_file "${local_dir}/settings.json"
        mkdir -p "${local_dir}"

        if ! dry_run "stow cursor"; then
            stow_module "cursor"
            success "Linked Cursor keybindings.json and settings.json"
        fi
    ) && track_module "Cursor" "installed" \
      || track_module "Cursor" "failed"
fi

# ===== MODULE 7: Stripe ======================================================
next_step "Stripe CLI Config"

if should_skip "stripe"; then
    warn "Skipped (--skip stripe)"
    track_module "Stripe" "skipped"
else
    (
        set -e
        stripe_config="${HOME}/.config/stripe/config.toml"
        stripe_example="${DOTFILES_DIR}/stow/stripe/.config/stripe/config.toml.example"
        mkdir -p "${HOME}/.config/stripe"

        if [[ -f "$stripe_config" ]]; then
            success "Stripe config already exists (not overwriting)"
            info "Template available at: ${DIM}${stripe_example}${RESET}"
        else
            if ! dry_run "Copy stripe config template"; then
                cp "$stripe_example" "$stripe_config"
                success "Copied Stripe config template"
                warn "Run ${BOLD}stripe login${RESET} to authenticate each project"
            fi
        fi
    ) && track_module "Stripe" "installed" \
      || track_module "Stripe" "failed"
fi

# ===== MODULE 8: Rectangle ===================================================
next_step "Rectangle Window Manager"

if should_skip "rectangle"; then
    warn "Skipped (--skip rectangle)"
    track_module "Rectangle" "skipped"
else
    (
        set -e
        plist_src="${DOTFILES_DIR}/stow/rectangle/Library/Preferences/com.knollsoft.Rectangle.plist"
        plist_dst="${HOME}/Library/Preferences/com.knollsoft.Rectangle.plist"

        backup_file "$plist_dst"

        if ! dry_run "Import Rectangle preferences"; then
            cp "$plist_src" "$plist_dst"
            defaults read com.knollsoft.Rectangle >/dev/null 2>&1
            success "Imported Rectangle preferences"
            warn "Restart Rectangle for changes to take effect"
        fi
    ) && track_module "Rectangle" "installed" \
      || track_module "Rectangle" "failed"
fi

# ===== MODULE 9: Fonts =======================================================
next_step "Fonts"

if should_skip "fonts"; then
    warn "Skipped (--skip fonts)"
    track_module "Fonts" "skipped"
else
    (
        set -e
        fonts_src="${DOTFILES_DIR}/fonts"
        fonts_dst="${HOME}/Library/Fonts"
        mkdir -p "$fonts_dst"

        installed=0
        skipped=0

        for font in "${fonts_src}"/*.ttf "${fonts_src}"/*.otf; do
            [[ -f "$font" ]] || continue
            fname="$(basename "$font")"

            if [[ -f "${fonts_dst}/${fname}" ]]; then
                if cmp -s "$font" "${fonts_dst}/${fname}"; then
                    ((skipped++))
                    continue
                fi
            fi

            if ! dry_run "Copy ${fname}"; then
                cp "$font" "${fonts_dst}/${fname}"
                ((installed++))
            fi
        done

        if (( installed > 0 )); then
            success "Installed ${installed} font(s), ${skipped} already up-to-date"
        else
            success "All ${skipped} fonts already up-to-date"
        fi
    ) && track_module "Fonts" "installed" \
      || track_module "Fonts" "failed"
fi

# ===== MODULE 10: macOS Defaults ==============================================
next_step "macOS Preferences"

if should_skip "macos"; then
    warn "Skipped (--skip macos)"
    track_module "macOS" "skipped"
else
    (
        set -e
        if ! dry_run "Apply macOS defaults"; then
            bash "${DOTFILES_DIR}/macos/defaults.sh"
            success "Applied macOS preferences"
        fi
    ) && track_module "macOS" "installed" \
      || track_module "macOS" "failed"
fi

# ===== MODULE 11: Raycast =====================================================
next_step "Raycast"

if should_skip "raycast"; then
    warn "Skipped (--skip raycast)"
    track_module "Raycast" "skipped"
else
    (
        success "Raycast requires manual import/export"
        info "See ${DIM}${DOTFILES_DIR}/raycast/README.md${RESET} for instructions"
        if [[ -f "${DOTFILES_DIR}/raycast/Raycast.rayconfig" ]]; then
            info "Config file available: ${DIM}raycast/Raycast.rayconfig${RESET}"
        fi
    ) && track_module "Raycast" "up-to-date" \
      || track_module "Raycast" "failed"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary
exit_code=$?

if [[ "$DRY_RUN" == "true" ]]; then
    printf "\n"
    warn "${BOLD}Dry run complete.${RESET} No changes were made."
    warn "Re-run without --dry-run to apply changes."
fi

printf "\n"
exit $exit_code
