#!/usr/bin/env bash
#
# Pull latest dotfiles and re-run the installer.
# Automatically detects work vs personal based on the Stripe shellinit.
#
# Usage: ./update.sh [any install.sh flags]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# shellcheck source=scripts/helpers.sh
source "${SCRIPT_DIR}/scripts/helpers.sh"

header "Updating Dotfiles"

info "Pulling latest changes..."
if git pull --ff-only; then
    success "Repository updated"
else
    error "git pull failed (you may have local changes)"
    info "Resolve conflicts, then re-run this script"
    exit 1
fi

ARGS=("$@")

# Auto-detect profile if --profile wasn't explicitly passed
has_profile=false
for arg in "${ARGS[@]}"; do
    [[ "$arg" == "--profile" ]] && has_profile=true
done

if [[ "$has_profile" == "false" ]]; then
    if [[ -f "${HOME}/.stripe/shellinit/zshrc" ]]; then
        info "Stripe shellinit detected — using ${BOLD}--profile work${RESET}"
        ARGS+=("--profile" "work")
    else
        info "No work environment detected — using ${BOLD}--profile personal${RESET}"
        ARGS+=("--profile" "personal")
    fi
fi

exec "${SCRIPT_DIR}/install.sh" "${ARGS[@]}"
