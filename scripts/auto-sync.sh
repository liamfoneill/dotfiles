#!/usr/bin/env bash
#
# Dotfiles auto-sync — runs via launchd on a schedule.
#
# Snapshots current symlinked configs, pulls latest changes, and sends a
# macOS notification if a re-run of install.sh is needed. Designed to run
# headless (no color, no interactive prompts).
#
# Usage: ./scripts/auto-sync.sh [--dotfiles-dir <path>]

DOTFILES_DIR="${DOTFILES_DIR:-${HOME}/dotfiles}"
SYNC_MAX_SNAPSHOTS="${SYNC_MAX_SNAPSHOTS:-10}"
BACKUP_BASE="${HOME}/.dotfiles-backup/auto-sync"
LOG_DIR="${HOME}/.local/share/dotfiles"
LOG_FILE="${LOG_DIR}/sync.log"
LOG_MAX_LINES=500

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dotfiles-dir) DOTFILES_DIR="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [[ ! -d "${DOTFILES_DIR}/.git" ]]; then
    echo "[error] Not a git repo: ${DOTFILES_DIR}"
    exit 1
fi

mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

rotate_log() {
    if [[ -f "$LOG_FILE" ]] && (( $(wc -l < "$LOG_FILE") > LOG_MAX_LINES )); then
        tail -n "$LOG_MAX_LINES" "$LOG_FILE" > "${LOG_FILE}.tmp"
        mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
}

notify() {
    local title="$1" message="$2"
    osascript -e "display notification \"${message}\" with title \"${title}\"" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Snapshot: copy current content of all stow-managed files
# ---------------------------------------------------------------------------
snapshot_configs() {
    local stow_dir="${DOTFILES_DIR}/stow"
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    local snap_dir="${BACKUP_BASE}/${timestamp}"
    local count=0

    for module_dir in "${stow_dir}"/*/; do
        [[ -d "$module_dir" ]] || continue
        while IFS= read -r -d '' file; do
            local relative="${file#"${module_dir}"}"
            local home_target="${HOME}/${relative}"

            [[ -e "$home_target" ]] || continue

            local dest="${snap_dir}/${relative}"
            mkdir -p "$(dirname "$dest")"

            if [[ -L "$home_target" ]]; then
                cp -L "$home_target" "$dest" 2>/dev/null && ((count++)) || true
            elif [[ -f "$home_target" ]]; then
                cp "$home_target" "$dest" 2>/dev/null && ((count++)) || true
            fi
        done < <(find "$module_dir" -type f -print0 2>/dev/null)
    done

    if (( count > 0 )); then
        log "Snapshot: ${count} files saved to ${timestamp}"
    else
        log "Snapshot: no files to save (first run?)"
        [[ -d "$snap_dir" ]] && rmdir "$snap_dir" 2>/dev/null || true
    fi
}

# ---------------------------------------------------------------------------
# Prune old snapshots beyond the retention limit
# ---------------------------------------------------------------------------
prune_snapshots() {
    [[ -d "$BACKUP_BASE" ]] || return 0

    local snapshots=()
    while IFS= read -r dir; do
        snapshots+=("$dir")
    done < <(ls -1t "$BACKUP_BASE" 2>/dev/null)

    if (( ${#snapshots[@]} > SYNC_MAX_SNAPSHOTS )); then
        local to_remove=("${snapshots[@]:$SYNC_MAX_SNAPSHOTS}")
        for old in "${to_remove[@]}"; do
            rm -rf "${BACKUP_BASE:?}/${old}"
            log "Pruned old snapshot: ${old}"
        done
    fi
}

# ---------------------------------------------------------------------------
# Detect whether non-symlinked files changed (needs install.sh re-run)
# ---------------------------------------------------------------------------
check_rerun_needed() {
    local before="$1" after="$2"
    local changed_files
    changed_files=$(git -C "$DOTFILES_DIR" diff "${before}" "${after}" --name-only 2>/dev/null)

    local reasons=()
    echo "$changed_files" | grep -q "^homebrew/"  && reasons+=("Brewfile changed")
    echo "$changed_files" | grep -q "^fonts/"     && reasons+=("Fonts changed")
    echo "$changed_files" | grep -q "^macos/"     && reasons+=("macOS defaults changed")
    echo "$changed_files" | grep -q "rectangle"   && reasons+=("Rectangle config changed")

    if (( ${#reasons[@]} > 0 )); then
        local detail
        detail=$(printf '%s, ' "${reasons[@]}")
        detail="${detail%, }"
        log "Re-run needed: ${detail}"
        notify "Dotfiles" "Re-run install.sh: ${detail}"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
log "--- sync started ---"

cd "$DOTFILES_DIR" || { log "Cannot cd to ${DOTFILES_DIR}"; exit 1; }

head_before=$(git rev-parse HEAD 2>/dev/null)

# Check if there are upstream changes before snapshotting
git fetch --quiet 2>/dev/null
upstream=$(git rev-parse '@{u}' 2>/dev/null || echo "")
if [[ -z "$upstream" ]]; then
    log "No upstream tracking branch — skipping"
    rotate_log
    exit 0
fi

if [[ "$head_before" == "$upstream" ]]; then
    log "Already up to date"
    rotate_log
    exit 0
fi

snapshot_configs

if git pull --ff-only --quiet 2>/dev/null; then
    head_after=$(git rev-parse HEAD 2>/dev/null)

    if [[ "$head_before" != "$head_after" ]]; then
        local_changes=$(git diff "${head_before}" "${head_after}" --stat 2>/dev/null | tail -1)
        log "Pulled: ${head_before:0:7} -> ${head_after:0:7} (${local_changes})"
        check_rerun_needed "$head_before" "$head_after"
    fi
else
    log "git pull --ff-only failed (local changes or diverged history?)"
    notify "Dotfiles" "Sync failed — git pull could not fast-forward. Run manually."
fi

prune_snapshots
rotate_log
log "--- sync finished ---"
