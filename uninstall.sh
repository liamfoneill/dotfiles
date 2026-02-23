#!/usr/bin/env bash
#
# Dotfiles uninstaller
#
# Removes symlinks created by install.sh and optionally restores backups.
#
# Usage: ./uninstall.sh [--restore]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "${SCRIPT_DIR}/scripts/helpers.sh"

RESTORE=false
if [[ "${1:-}" == "--restore" ]]; then
    RESTORE=true
fi

printf "\n"
printf "  ${BOLD}${CYAN}┌─────────────────────────────────────┐${RESET}\n"
printf "  ${BOLD}${CYAN}│         Dotfiles Uninstaller        │${RESET}\n"
printf "  ${BOLD}${CYAN}└─────────────────────────────────────┘${RESET}\n"
printf "\n"

header "Removing Symlinks"

STOW_PACKAGES=("zsh" "git" "starship" "ghostty" "yazi" "hammerspoon" "vscode" "cursor")

for pkg in "${STOW_PACKAGES[@]}"; do
    if [[ -d "${STOW_DIR}/${pkg}" ]]; then
        if unstow_module "$pkg" 2>/dev/null; then
            success "Removed ${pkg} symlinks"
        else
            warn "Could not remove ${pkg} symlinks (may not have been installed)"
        fi
    fi
done

# Profile-specific zshrc symlinks (only one exists depending on profile)
for profile_rc in ".zshrc.work" ".zshrc.personal"; do
    if [[ -L "${HOME}/${profile_rc}" ]]; then
        rm "${HOME}/${profile_rc}"
        success "Removed ${profile_rc} symlink"
    fi
done

# Rectangle is copied (not stowed), so remove the plist directly
header "Removing Copied Configs"

rect_plist="${HOME}/Library/Preferences/com.knollsoft.Rectangle.plist"
if [[ -f "$rect_plist" ]]; then
    rm "$rect_plist"
    success "Removed Rectangle preferences"
    warn "Restart Rectangle to regenerate defaults"
else
    info "Rectangle plist not found (already removed or never installed)"
fi

if [[ "$RESTORE" == "true" ]]; then
    header "Restoring Backups"

    BACKUP_BASE="${HOME}/.dotfiles-backup"

    if [[ -d "$BACKUP_BASE" ]]; then
        latest=$(ls -1t "$BACKUP_BASE" 2>/dev/null | head -1)
        if [[ -n "$latest" ]]; then
            info "Restoring from backup: ${DIM}${latest}${RESET}"
            restore_dir="${BACKUP_BASE}/${latest}"

            # Restore files from the backup
            while IFS= read -r -d '' file; do
                relative="${file#"${restore_dir}"/}"
                target="${HOME}/${relative}"
                mkdir -p "$(dirname "$target")"
                cp -R "$file" "$target"
                success "Restored ${relative}"
            done < <(find "$restore_dir" -type f -print0 2>/dev/null)
        else
            warn "No backups found in ${BACKUP_BASE}"
        fi
    else
        warn "No backup directory found at ${BACKUP_BASE}"
    fi
fi

header "Summary"
success "Dotfiles symlinks removed"

if [[ "$RESTORE" == "true" ]]; then
    success "Backups restored from latest snapshot"
else
    info "Run with ${BOLD}--restore${RESET} to also restore backed-up files"
fi

printf "\n"
info "Note: Homebrew packages, fonts, and macOS defaults are not reverted."
info "Remove those manually if needed."
printf "\n"
