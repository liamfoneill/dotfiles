#!/usr/bin/env bash
# Shared helper functions for install/uninstall scripts.
# Note: this file is sourced, so it does NOT set shell options.
# Callers should set their own `set -euo pipefail` as needed.

# ---------------------------------------------------------------------------
# Colors and formatting
# ---------------------------------------------------------------------------
readonly BOLD="\033[1m"
readonly DIM="\033[2m"
readonly RESET="\033[0m"
readonly RED="\033[0;31m"
readonly GREEN="\033[0;32m"
readonly YELLOW="\033[0;33m"
readonly BLUE="\033[0;34m"
readonly CYAN="\033[0;36m"
readonly WHITE="\033[1;37m"

readonly CHECK="${GREEN}✓${RESET}"
readonly CROSS="${RED}✗${RESET}"
readonly ARROW="${BLUE}→${RESET}"
readonly WARN="${YELLOW}!${RESET}"
readonly SKIP="${DIM}○${RESET}"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
info()    { printf "  ${ARROW} %b\n" "$1"; }
success() { printf "  ${CHECK} %b\n" "$1"; }
warn()    { printf "  ${WARN} %b\n" "$1"; }
error()   { printf "  ${CROSS} %b\n" "$1" >&2; }

header() {
    printf "\n${WHITE}━━━ %s ━━━${RESET}\n\n" "$1"
}

step() {
    local current="$1" total="$2" label="$3"
    printf "\n${CYAN}[%d/%d]${RESET} ${BOLD}%s${RESET}\n" "$current" "$total" "$label"
}

# ---------------------------------------------------------------------------
# Summary report tracking
# ---------------------------------------------------------------------------
declare -a MODULE_NAMES=()
declare -a MODULE_STATUSES=()

track_module() {
    local name="$1" status="$2"
    MODULE_NAMES+=("$name")
    MODULE_STATUSES+=("$status")
}

print_summary() {
    header "Summary Report"

    local installed=0 skipped=0 failed=0 up_to_date=0

    printf "  ${DIM}%-20s %s${RESET}\n" "MODULE" "STATUS"
    printf "  ${DIM}%-20s %s${RESET}\n" "────────────────────" "──────────────────"

    for i in "${!MODULE_NAMES[@]}"; do
        local name="${MODULE_NAMES[$i]}"
        local status="${MODULE_STATUSES[$i]}"
        local icon

        case "$status" in
            installed)    icon="${CHECK}"; ((installed++)) ;;
            skipped)      icon="${SKIP}"; ((skipped++)) ;;
            failed)       icon="${CROSS}"; ((failed++)) ;;
            up-to-date)   icon="${CHECK}"; ((up_to_date++)) ;;
            *)            icon="${DIM}?${RESET}" ;;
        esac

        printf "  %-20s %b %s\n" "$name" "$icon" "$status"
    done

    printf "\n  ${DIM}────────────────────────────────────${RESET}\n"
    printf "  ${GREEN}Installed:${RESET}  %d\n" "$installed"
    printf "  ${GREEN}Up-to-date:${RESET} %d\n" "$up_to_date"
    printf "  ${YELLOW}Skipped:${RESET}    %d\n" "$skipped"
    printf "  ${RED}Failed:${RESET}     %d\n" "$failed"
    printf "\n"

    if (( failed > 0 )); then
        warn "Some modules failed. Re-run with verbose output to debug."
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Backup utility (copy-only — does NOT remove the original)
# ---------------------------------------------------------------------------
BACKUP_DIR="${HOME}/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"

backup_file() {
    local file="$1"
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        if [[ -e "$file" || -L "$file" ]]; then
            local relative="${file#"$HOME"/}"
            info "${DIM}[dry-run]${RESET} Would back up ${DIM}${relative}${RESET}"
        fi
        return 0
    fi
    if [[ -L "$file" ]]; then
        local relative="${file#"$HOME"/}"
        local dest="${BACKUP_DIR}/${relative}.symlink"
        mkdir -p "$(dirname "$dest")"
        readlink "$file" > "$dest"
        info "Backed up symlink ${DIM}${relative}${RESET}"
    elif [[ -e "$file" ]]; then
        mkdir -p "$BACKUP_DIR"
        local relative="${file#"$HOME"/}"
        local dest="${BACKUP_DIR}/${relative}"
        mkdir -p "$(dirname "$dest")"
        cp -R "$file" "$dest"
        info "Backed up ${DIM}${relative}${RESET}"
    fi
}

# ---------------------------------------------------------------------------
# Remove a file to make way for stow (call after backup_file, inside dry_run guard)
# ---------------------------------------------------------------------------
remove_for_stow() {
    local file="$1"
    if [[ -L "$file" ]]; then
        rm "$file"
    elif [[ -e "$file" ]]; then
        rm -rf "$file"
    fi
}

# ---------------------------------------------------------------------------
# Stow wrapper
# ---------------------------------------------------------------------------
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STOW_DIR="${DOTFILES_DIR}/stow"

stow_module() {
    local module="$1"
    local target="${2:-$HOME}"

    if [[ ! -d "${STOW_DIR}/${module}" ]]; then
        error "Stow package '${module}' not found at ${STOW_DIR}/${module}"
        return 1
    fi

    stow --restow --dir="$STOW_DIR" --target="$target" "$module" 2>&1
}

unstow_module() {
    local module="$1"
    local target="${2:-$HOME}"

    if [[ ! -d "${STOW_DIR}/${module}" ]]; then
        warn "Stow package '${module}' not found, skipping"
        return 0
    fi

    stow --delete --dir="$STOW_DIR" --target="$target" "$module" 2>&1
}

# ---------------------------------------------------------------------------
# Dry-run support
# ---------------------------------------------------------------------------
DRY_RUN="${DRY_RUN:-false}"

dry_run() {
    if [[ "$DRY_RUN" == "true" ]]; then
        info "${DIM}[dry-run]${RESET} $1"
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
require_command() {
    local cmd="$1"
    local install_hint="${2:-}"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error "'${cmd}' is required but not installed."
        [[ -n "$install_hint" ]] && info "Install with: ${install_hint}"
        return 1
    fi
}

is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}
