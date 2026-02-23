#!/usr/bin/env bash
#
# Dotfiles bootstrap — run this on a brand new Mac.
#
# Installs Xcode CLT, Homebrew, clones the repo, and runs install.sh.
# All arguments are forwarded to install.sh.
#
# Usage (from a bare Mac with only curl):
#   bash <(curl -fsSL https://raw.githubusercontent.com/liamfoneill/dotfiles/main/scripts/bootstrap.sh) --profile personal
#   bash <(curl -fsSL https://raw.githubusercontent.com/liamfoneill/dotfiles/main/scripts/bootstrap.sh) --profile work
#
# Or if you already have the repo cloned:
#   ./scripts/bootstrap.sh --profile personal

set -uo pipefail

REPO_URL="https://github.com/liamfoneill/dotfiles.git"
DOTFILES_DIR="${HOME}/dotfiles"

BOLD="\033[1m"
DIM="\033[2m"
RESET="\033[0m"
CYAN="\033[0;36m"

info()    { printf "  \033[0;34m→\033[0m %b\n" "$1"; }
success() { printf "  \033[0;32m✓\033[0m %b\n" "$1"; }
error()   { printf "  \033[0;31m✗\033[0m %b\n" "$1" >&2; }

printf "\n"
printf "  ${BOLD}${CYAN}┌─────────────────────────────────────┐${RESET}\n"
printf "  ${BOLD}${CYAN}│        Dotfiles Bootstrap           │${RESET}\n"
printf "  ${BOLD}${CYAN}└─────────────────────────────────────┘${RESET}\n"
printf "\n"

# ---------------------------------------------------------------------------
# Step 1: Xcode Command Line Tools
# ---------------------------------------------------------------------------
if ! xcode-select -p >/dev/null 2>&1; then
    info "Installing Xcode Command Line Tools (this may take a few minutes)..."
    xcode-select --install 2>/dev/null

    info "Waiting for Xcode CLT installation to complete..."
    until xcode-select -p >/dev/null 2>&1; do sleep 5; done
    success "Xcode Command Line Tools installed"
else
    success "Xcode Command Line Tools already installed"
fi

# ---------------------------------------------------------------------------
# Step 2: Homebrew
# ---------------------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    if ! command -v brew >/dev/null 2>&1; then
        error "Homebrew installation failed"
        exit 1
    fi
    success "Homebrew installed"
else
    success "Homebrew already installed"
fi

# ---------------------------------------------------------------------------
# Step 3: Git (should be available via CLT, but verify)
# ---------------------------------------------------------------------------
if ! command -v git >/dev/null 2>&1; then
    info "Installing git via Homebrew..."
    brew install git
    success "Git installed"
else
    success "Git available ($(git --version | awk '{print $3}'))"
fi

# ---------------------------------------------------------------------------
# Step 4: Clone or update the repo
# ---------------------------------------------------------------------------
if [[ -d "${DOTFILES_DIR}/.git" ]]; then
    info "Dotfiles repo already exists at ${DIM}${DOTFILES_DIR}${RESET}"
    info "Pulling latest changes..."
    git -C "$DOTFILES_DIR" pull --ff-only || {
        error "git pull failed — resolve conflicts in ${DOTFILES_DIR} and re-run"
        exit 1
    }
    success "Repository updated"
else
    info "Cloning dotfiles to ${DIM}${DOTFILES_DIR}${RESET}..."
    git clone "$REPO_URL" "$DOTFILES_DIR" || {
        error "git clone failed"
        exit 1
    }
    success "Repository cloned"
fi

# ---------------------------------------------------------------------------
# Step 5: Run install.sh (forward all arguments)
# ---------------------------------------------------------------------------
printf "\n"
info "Running installer..."
printf "\n"

exec "${DOTFILES_DIR}/install.sh" "$@"
