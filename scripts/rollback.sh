#!/usr/bin/env bash
#
# Dotfiles rollback — list and restore config snapshots.
#
# Snapshots are created by:
#   - auto-sync.sh (pre-pull)  -> ~/.dotfiles-backup/auto-sync/<timestamp>/
#   - install.sh (pre-stow)    -> ~/.dotfiles-backup/<timestamp>/
#
# Usage:
#   ./scripts/rollback.sh                 # List available snapshots
#   ./scripts/rollback.sh <timestamp>     # Restore a specific snapshot
#   ./scripts/rollback.sh --latest        # Restore the most recent snapshot

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=helpers.sh
source "${SCRIPT_DIR}/helpers.sh"

BACKUP_BASE="${HOME}/.dotfiles-backup"

# ---------------------------------------------------------------------------
# Gather all snapshots (auto-sync and install.sh) sorted newest-first
# ---------------------------------------------------------------------------
gather_snapshots() {
    local entries=()

    if [[ -d "${BACKUP_BASE}/auto-sync" ]]; then
        for dir in "${BACKUP_BASE}/auto-sync"/*/; do
            [[ -d "$dir" ]] || continue
            local name
            name=$(basename "$dir")
            entries+=("${name}|auto-sync|${dir}")
        done
    fi

    for dir in "${BACKUP_BASE}"/*/; do
        [[ -d "$dir" ]] || continue
        local name
        name=$(basename "$dir")
        [[ "$name" == "auto-sync" ]] && continue
        entries+=("${name}|install|${dir}")
    done

    # Sort by timestamp descending
    printf '%s\n' "${entries[@]}" | sort -t'|' -k1 -r
}

# ---------------------------------------------------------------------------
# List snapshots
# ---------------------------------------------------------------------------
list_snapshots() {
    header "Available Snapshots"

    local snapshots
    snapshots=$(gather_snapshots)

    if [[ -z "$snapshots" ]]; then
        warn "No snapshots found in ${BACKUP_BASE}"
        return 1
    fi

    printf "  ${DIM}%-20s %-12s %s${RESET}\n" "TIMESTAMP" "SOURCE" "FILES"
    printf "  ${DIM}%-20s %-12s %s${RESET}\n" "────────────────────" "────────────" "─────"

    while IFS='|' read -r timestamp source dir; do
        local count
        count=$(/usr/bin/find "$dir" -type f 2>/dev/null | wc -l | tr -d ' ')
        printf "  %-20s %-12s %s\n" "$timestamp" "$source" "${count} files"
    done <<< "$snapshots"

    printf "\n"
    info "Restore with: ${BOLD}./scripts/rollback.sh <timestamp>${RESET}"
    info "Or restore latest: ${BOLD}./scripts/rollback.sh --latest${RESET}"
}

# ---------------------------------------------------------------------------
# Find the snapshot directory for a given timestamp
# ---------------------------------------------------------------------------
find_snapshot_dir() {
    local target="$1"

    if [[ -d "${BACKUP_BASE}/auto-sync/${target}" ]]; then
        echo "${BACKUP_BASE}/auto-sync/${target}"
        return 0
    fi

    if [[ -d "${BACKUP_BASE}/${target}" ]]; then
        echo "${BACKUP_BASE}/${target}"
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# Show diff between snapshot and current repo state
# ---------------------------------------------------------------------------
show_diff() {
    local snap_dir="$1"
    local changes=0

    while IFS= read -r -d '' file; do
        local relative="${file#"${snap_dir}"/}"

        # Map back to the repo source file by searching stow modules
        local repo_file=""
        for module_dir in "${STOW_DIR}"/*/; do
            [[ -d "$module_dir" ]] || continue
            if [[ -f "${module_dir}${relative}" ]]; then
                repo_file="${module_dir}${relative}"
                break
            fi
        done

        if [[ -z "$repo_file" ]]; then
            info "${DIM}${relative}${RESET} — not in repo (skipping)"
            continue
        fi

        if ! cmp -s "$file" "$repo_file"; then
            printf "  ${YELLOW}changed${RESET}  %s\n" "$relative"
            ((changes++))
        fi
    done < <(/usr/bin/find "$snap_dir" -type f -print0 2>/dev/null)

    return "$changes"
}

# ---------------------------------------------------------------------------
# Restore snapshot files into the repo
# ---------------------------------------------------------------------------
restore_snapshot() {
    local snap_dir="$1"
    local restored=0 skipped=0

    while IFS= read -r -d '' file; do
        local relative="${file#"${snap_dir}"/}"

        local repo_file=""
        for module_dir in "${STOW_DIR}"/*/; do
            [[ -d "$module_dir" ]] || continue
            if [[ -f "${module_dir}${relative}" ]]; then
                repo_file="${module_dir}${relative}"
                break
            fi
        done

        if [[ -z "$repo_file" ]]; then
            ((skipped++))
            continue
        fi

        if cmp -s "$file" "$repo_file"; then
            ((skipped++))
            continue
        fi

        cp "$file" "$repo_file"
        success "Restored ${relative}"
        ((restored++))
    done < <(/usr/bin/find "$snap_dir" -type f -print0 2>/dev/null)

    printf "\n"
    info "Restored ${BOLD}${restored}${RESET} file(s), ${skipped} unchanged/skipped"
    if (( restored > 0 )); then
        info "Changes are in the repo. Symlinked configs are already updated."
        info "Commit if you want to keep the rollback: ${DIM}cd ${DOTFILES_DIR} && git add -A && git commit -m 'Rollback'${RESET}"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
printf "\n"
printf "  ${BOLD}${CYAN}┌─────────────────────────────────────┐${RESET}\n"
printf "  ${BOLD}${CYAN}│         Dotfiles Rollback           │${RESET}\n"
printf "  ${BOLD}${CYAN}└─────────────────────────────────────┘${RESET}\n"
printf "\n"

if [[ $# -eq 0 ]]; then
    list_snapshots
    exit 0
fi

target="$1"

if [[ "$target" == "--latest" ]]; then
    latest_line=$(gather_snapshots | head -1)
    if [[ -z "$latest_line" ]]; then
        error "No snapshots found"
        exit 1
    fi
    target=$(echo "$latest_line" | cut -d'|' -f1)
    source_type=$(echo "$latest_line" | cut -d'|' -f2)
    info "Latest snapshot: ${BOLD}${target}${RESET} (${source_type})"
fi

snap_dir=$(find_snapshot_dir "$target")
if [[ -z "$snap_dir" ]]; then
    error "Snapshot not found: ${target}"
    info "Run ${BOLD}./scripts/rollback.sh${RESET} to list available snapshots"
    exit 1
fi

header "Changes to Restore"

show_diff "$snap_dir"
diff_count=$?

if (( diff_count == 0 )); then
    success "Snapshot matches current state — nothing to restore"
    exit 0
fi

printf "\n"
printf "  Restore ${BOLD}%d${RESET} file(s) from snapshot ${BOLD}%s${RESET}?\n" "$diff_count" "$target"
printf "  This overwrites repo files (symlinked configs update instantly).\n\n"
read -rp "  Proceed? [y/N] " confirm
printf "\n"

if [[ "${confirm,,}" != "y" ]]; then
    info "Cancelled"
    exit 0
fi

header "Restoring"
restore_snapshot "$snap_dir"
printf "\n"
