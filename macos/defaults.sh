#!/usr/bin/env bash
#
# macOS system preferences via `defaults write`.
# These are idempotent — safe to run multiple times.
#
# Some changes require a logout/restart or a Finder restart to take effect.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/helpers.sh"

header "macOS Preferences"

# =============================================================================
# Finder
# =============================================================================

info "Configuring Finder..."

# Show hidden files in Finder
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show all file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show path bar at bottom of Finder
defaults write com.apple.finder ShowPathbar -bool true

# Show status bar at bottom of Finder
defaults write com.apple.finder ShowStatusBar -bool true

# Default to list view in Finder (icnv=icon, Nlsv=list, clmv=column, Flwv=gallery)
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Disable warning when changing file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# New Finder windows open to home directory
defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"

# Show the ~/Library folder
chflags nohidden ~/Library 2>/dev/null || true

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

success "Finder preferences"

# =============================================================================
# Dock
# =============================================================================

info "Configuring Dock..."

# Set Dock icon size
defaults write com.apple.dock tilesize -int 48

# Enable Dock magnification
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -int 64

# Minimize windows using scale effect (genie | scale | suck)
defaults write com.apple.dock mineffect -string "scale"

# Don't show recent applications in Dock
defaults write com.apple.dock show-recents -bool false

# Auto-hide the Dock
defaults write com.apple.dock autohide -bool true

# Remove the auto-hiding Dock delay
defaults write com.apple.dock autohide-delay -float 0

# Speed up the Dock animation
defaults write com.apple.dock autohide-time-modifier -float 0.3

success "Dock preferences"

# =============================================================================
# Keyboard & Input
# =============================================================================

info "Configuring keyboard..."

# Fast key repeat rate
defaults write NSGlobalDomain KeyRepeat -int 2

# Short delay until key repeat
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Disable automatic capitalization
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Disable automatic period substitution (double-space -> period)
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Disable smart quotes and dashes (breaks code in terminal)
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

success "Keyboard preferences"

# =============================================================================
# Trackpad
# =============================================================================

info "Configuring trackpad..."

# Enable tap to click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Enable three-finger drag
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true

success "Trackpad preferences"

# =============================================================================
# Screenshots
# =============================================================================

info "Configuring screenshots..."

# Save screenshots to ~/Screenshots
mkdir -p "${HOME}/Screenshots"
defaults write com.apple.screencapture location -string "${HOME}/Screenshots"

# Save screenshots as PNG
defaults write com.apple.screencapture type -string "png"

# Disable shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true

success "Screenshot preferences"

# =============================================================================
# Mission Control & Spaces
# =============================================================================

info "Configuring Mission Control..."

# Don't automatically rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

# Group windows by application in Mission Control
defaults write com.apple.dock expose-group-by-app -bool true

success "Mission Control preferences"

# =============================================================================
# Finder Sidebar Favorites
# =============================================================================

info "Configuring Finder sidebar..."

if command -v mysides >/dev/null 2>&1; then
    # Shared sidebar items (both machines)
    mysides add "Home" "file://${HOME}/" 2>/dev/null || true
    mysides add "Desktop" "file://${HOME}/Desktop/" 2>/dev/null || true
    mysides add "Downloads" "file://${HOME}/Downloads/" 2>/dev/null || true
    mysides add "Documents" "file://${HOME}/Documents/" 2>/dev/null || true
    mysides add "Screenshots" "file://${HOME}/Screenshots/" 2>/dev/null || true
    mysides add "Applications" "file:///Applications/" 2>/dev/null || true

    # Machine-specific sidebar items from ~/.dotfiles-sidebar
    # Create this file on each machine with one entry per line: "Label|/path/to/folder"
    #
    # Work example (~/.dotfiles-sidebar):
    #   GitHub|~/stripe/Github
    #   GitHub Enterprise|~/stripe/Github-Enterprise
    #   Google Drive|~/Library/CloudStorage/GoogleDrive
    #
    # Personal example (~/.dotfiles-sidebar):
    #   GitHub|~/Developer/Github
    #   iCloud|~/Library/Mobile Documents/com~apple~CloudDocs
    #
    sidebar_file="${HOME}/.dotfiles-sidebar"
    if [[ -f "$sidebar_file" ]]; then
        while IFS='|' read -r label path || [[ -n "$label" ]]; do
            [[ -z "$label" || "$label" == \#* ]] && continue
            expanded_path="${path/#\~/$HOME}"
            if [[ -d "$expanded_path" ]]; then
                mysides add "$label" "file://${expanded_path}/" 2>/dev/null || true
                success "Sidebar: ${label} → ${DIM}${path}${RESET}"
            else
                warn "Sidebar: ${label} — path not found: ${path}"
            fi
        done < "$sidebar_file"
    else
        info "No machine-specific sidebar items (create ${DIM}~/.dotfiles-sidebar${RESET} to add)"
    fi

    success "Finder sidebar favorites configured"
else
    warn "mysides not installed — Finder sidebar favorites must be configured manually"
    info "Install with: ${DIM}brew install mysides${RESET}"
fi

# =============================================================================
# Apply changes
# =============================================================================

info "Restarting affected applications..."

for app in "Finder" "Dock" "SystemUIServer"; do
    killall "$app" 2>/dev/null || true
done

success "macOS preferences applied"
warn "Some changes may require a logout/restart to take full effect"
