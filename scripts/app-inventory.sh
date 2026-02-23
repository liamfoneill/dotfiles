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

# ── Build lookup tables (Bash 3.2 compatible — no associative arrays) ────────

# Homebrew cask names don't match /Applications names, so we build a
# newline-delimited list of .app bundles Homebrew installed.
brew_managed=""
caskroom="$(brew --caskroom 2>/dev/null || true)"
if [[ -n "$caskroom" && -d "$caskroom" ]]; then
    for cask_dir in "${caskroom}"/*/; do
        [[ -d "$cask_dir" ]] || continue
        for version_dir in "${cask_dir}"*/; do
            [[ -d "$version_dir" ]] || continue
            for app in "${version_dir}"*.app; do
                [[ -e "$app" ]] || continue
                brew_managed="${brew_managed}|$(basename "$app")"
            done
        done
    done
fi

system_apps="|Safari.app|Xcode.app|GarageBand.app|iMovie.app|Keynote.app|Numbers.app|Pages.app|Utilities|"

corp_apps="|Santa.app|SentinelOne|Managed Software Center.app|Bigmac.app|CodeReview.app|MacMove.app|DemoPro.app|YubiKey Manager.app|YubiKey Personalization Tool.app|"

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

        if [[ "$system_apps" == *"|${name}|"* ]]; then
            tag="system"
        elif [[ "$corp_apps" == *"|${name}|"* ]]; then
            tag="corp"
        elif [[ "$brew_managed" == *"|${name}|"* || "$brew_managed" == *"|${name}" ]]; then
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
