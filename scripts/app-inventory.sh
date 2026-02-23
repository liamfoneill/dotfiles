#!/usr/bin/env bash
#
# Scan /Applications and write a tagged inventory file.
# Read-only — lists apps, installs nothing.
#
# Usage: ./scripts/app-inventory.sh [work|personal]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INVENTORY_DIR="${DOTFILES_DIR}/inventory"

profile="${1:-}"
if [[ -z "$profile" ]]; then
    if [[ -f "${HOME}/.stripe/shellinit/zshrc" ]]; then
        profile="work"
    else
        profile="personal"
    fi
    echo "Auto-detected profile: ${profile}"
fi

if [[ "$profile" != "work" && "$profile" != "personal" ]]; then
    echo "Usage: $0 [work|personal]" >&2
    exit 1
fi

outfile="${INVENTORY_DIR}/apps-${profile}.txt"
mkdir -p "$INVENTORY_DIR"

# ── Build lookup tables ──────────────────────────────────────────────────────

# Homebrew cask names don't match /Applications names, so we build a
# reverse map from the actual .app bundles Homebrew installed.
declare -A brew_managed=()
caskroom="$(brew --caskroom 2>/dev/null || true)"
if [[ -n "$caskroom" && -d "$caskroom" ]]; then
    for cask_dir in "${caskroom}"/*/; do
        [[ -d "$cask_dir" ]] || continue
        for version_dir in "${cask_dir}"*/; do
            [[ -d "$version_dir" ]] || continue
            for app in "${version_dir}"*.app; do
                [[ -e "$app" ]] || continue
                brew_managed["$(basename "$app")"]=1
            done
        done
    done
fi

declare -A system_apps=(
    ["Safari.app"]=1
    ["Xcode.app"]=1
    ["GarageBand.app"]=1
    ["iMovie.app"]=1
    ["Keynote.app"]=1
    ["Numbers.app"]=1
    ["Pages.app"]=1
    ["Utilities"]=1
)

declare -A corp_apps=(
    ["Santa.app"]=1
    ["SentinelOne"]=1
    ["Managed Software Center.app"]=1
    ["Bigmac.app"]=1
    ["CodeReview.app"]=1
    ["MacMove.app"]=1
    ["DemoPro.app"]=1
    ["YubiKey Manager.app"]=1
    ["YubiKey Personalization Tool.app"]=1
)

# ── Scan /Applications ───────────────────────────────────────────────────────

hostname="$(scutil --get ComputerName 2>/dev/null || hostname -s)"
date_str="$(date +%Y-%m-%d)"

{
    cat <<EOF
# Applications — ${profile} (${hostname})
# Generated: ${date_str}
#
# Source legend:
#   [brew]   Managed by Homebrew cask
#   [system] Ships with macOS
#   [corp]   Corporate / MDM managed
#   [manual] Installed manually (direct download, App Store, etc.)
#
# Run on the other machine and diff to compare:
#   diff inventory/apps-work.txt inventory/apps-personal.txt

EOF

    for entry in /Applications/*; do
        name="$(basename "$entry")"

        if [[ -n "${system_apps[$name]:-}" ]]; then
            tag="system"
        elif [[ -n "${corp_apps[$name]:-}" ]]; then
            tag="corp"
        elif [[ -n "${brew_managed[$name]:-}" ]]; then
            tag="brew"
        else
            tag="manual"
        fi

        printf "%-45s [%s]\n" "$name" "$tag"
    done
} > "$outfile"

app_count=$(/usr/bin/grep -c '^\S' "$outfile")
brew_count=$(/usr/bin/grep -c '\[brew\]' "$outfile" || true)
system_count=$(/usr/bin/grep -c '\[system\]' "$outfile" || true)
corp_count=$(/usr/bin/grep -c '\[corp\]' "$outfile" || true)
manual_count=$(/usr/bin/grep -c '\[manual\]' "$outfile" || true)

echo ""
echo "  Wrote: ${outfile}"
echo ""
echo "  Total:   ${app_count}"
echo "  [brew]   ${brew_count}"
echo "  [system] ${system_count}"
echo "  [corp]   ${corp_count}"
echo "  [manual] ${manual_count}"
echo ""
echo "  Commit this file and run on your other machine to compare."
echo ""
