### ===========================================================================
### ~/.zshrc — Shared base configuration
###
### This file is managed by dotfiles (symlinked via GNU Stow).
### Profile overrides (only one is symlinked per machine):
###   Work:     ~/.zshrc.work     (--profile work)
###   Personal: ~/.zshrc.personal (--profile personal)
### Machine-specific overrides:   ~/.zshrc.local (not in repo)
###
### Packages expected (optional, safe if missing):
###   brew install zsh-autosuggestions zsh-completions fzf
### ===========================================================================


### ---------------------------------------------------------------------------
### Profile config (only the active profile's file will be present)
### ---------------------------------------------------------------------------
if [[ -f "${HOME}/.zshrc.work" ]]; then
    source "${HOME}/.zshrc.work"
fi

if [[ -f "${HOME}/.zshrc.personal" ]]; then
    source "${HOME}/.zshrc.personal"
fi


### ---------------------------------------------------------------------------
### 0) Aliases and env vars
### ---------------------------------------------------------------------------

alias python="python3"
alias pip="pip3"
alias cls="clear"

export EDITOR="cursor --wait"
export LANG="en_US.UTF-8"
export DIRENV_LOG_FORMAT=


### ---------------------------------------------------------------------------
### 1) Homebrew prefix detection
### ---------------------------------------------------------------------------

if command -v brew >/dev/null 2>&1; then
    HOMEBREW_PREFIX="$(brew --prefix)"
else
    if [[ -d "/opt/homebrew" ]]; then
        HOMEBREW_PREFIX="/opt/homebrew"
    elif [[ -d "/usr/local" ]]; then
        HOMEBREW_PREFIX="/usr/local"
    else
        HOMEBREW_PREFIX=""
    fi
fi


### ---------------------------------------------------------------------------
### 2) bun
### ---------------------------------------------------------------------------

export BUN_INSTALL="${HOME}/.bun"
export PATH="${BUN_INSTALL}/bin:${PATH}"


### ---------------------------------------------------------------------------
### 3) Zsh completions (fpath before compinit)
### ---------------------------------------------------------------------------

fpath=(
    "${HOME}/.docker/completions"
    "${HOME}/.stripe"
    $fpath
)

if [[ -n "${HOMEBREW_PREFIX}" ]]; then
    if [[ -d "${HOMEBREW_PREFIX}/share/zsh-completions" ]]; then
        fpath=("${HOMEBREW_PREFIX}/share/zsh-completions" $fpath)
    fi
    if [[ -d "${HOMEBREW_PREFIX}/share/zsh/site-functions" ]]; then
        fpath=("${HOMEBREW_PREFIX}/share/zsh/site-functions" $fpath)
    fi
fi

_ZSH_CLI_COMP_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/zsh/completions"
mkdir -p "${_ZSH_CLI_COMP_DIR}" 2>/dev/null
fpath=("${_ZSH_CLI_COMP_DIR}" $fpath)


### ---------------------------------------------------------------------------
### 4) compinit (once)
### ---------------------------------------------------------------------------

autoload -Uz compinit
compinit


### ---------------------------------------------------------------------------
### 5) Stripe CLI alias fix (1Password plugin conflict)
### ---------------------------------------------------------------------------

unalias stripe 2>/dev/null

if [[ -n "${HOMEBREW_PREFIX}" && -x "${HOMEBREW_PREFIX}/bin/stripe" ]]; then
    alias stripe="${HOMEBREW_PREFIX}/bin/stripe"
else
    alias stripe="/usr/local/bin/stripe"
fi


### ---------------------------------------------------------------------------
### 6) 1Password CLI completions
### ---------------------------------------------------------------------------

if command -v op >/dev/null 2>&1; then
    eval "$(op completion zsh)"
    compdef _op op
fi


### ---------------------------------------------------------------------------
### 7) fzf history search
### ---------------------------------------------------------------------------

if [[ -n "${HOMEBREW_PREFIX}" && -f "${HOMEBREW_PREFIX}/opt/fzf/shell/key-bindings.zsh" ]]; then
    source "${HOMEBREW_PREFIX}/opt/fzf/shell/key-bindings.zsh"
fi

export FZF_DEFAULT_OPTS="--height=60% --layout=reverse --border --prompt=\"history> \" --preview-window=down:40%:wrap"
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window=down:40%:wrap --bind 'ctrl-j:down,ctrl-k:up'"

if command -v fzf >/dev/null 2>&1; then
    bindkey "^R" fzf-history-widget
fi


### ---------------------------------------------------------------------------
### 8) zsh-autosuggestions
### ---------------------------------------------------------------------------

if [[ -n "${HOMEBREW_PREFIX}" && -f "${HOMEBREW_PREFIX}/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "${HOMEBREW_PREFIX}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_USE_ASYNC=true
fi


### ---------------------------------------------------------------------------
### 9) Arrow key behavior
### ---------------------------------------------------------------------------

function _right_arrow_accept_or_forward() {
    if (( CURSOR == ${#BUFFER} )) && [[ -n "${POSTDISPLAY}" ]] && zle -l autosuggest-accept >/dev/null 2>&1; then
        zle autosuggest-accept
        return
    fi
    zle forward-char
}
zle -N _right_arrow_accept_or_forward

bindkey "^[[C" _right_arrow_accept_or_forward
bindkey "^[OC" _right_arrow_accept_or_forward

bindkey "^[[D" backward-char
bindkey "^[OD" backward-char
bindkey "^[[A" up-line-or-history
bindkey "^[OA" up-line-or-history
bindkey "^[[B" down-line-or-history
bindkey "^[OB" down-line-or-history

bindkey "^F" _right_arrow_accept_or_forward

function _opt_right_accept_word_or_forward_word() {
    if (( CURSOR == ${#BUFFER} )) && [[ -n "${POSTDISPLAY}" ]] && zle -l autosuggest-accept-word >/dev/null 2>&1; then
        zle autosuggest-accept-word
        return
    fi
    zle forward-word
}
zle -N _opt_right_accept_word_or_forward_word

bindkey "^[^[[C" _opt_right_accept_word_or_forward_word
bindkey "^[\[1;3C" _opt_right_accept_word_or_forward_word


### ---------------------------------------------------------------------------
### 10) fzf completion
### ---------------------------------------------------------------------------

if [[ -n "${HOMEBREW_PREFIX}" && -f "${HOMEBREW_PREFIX}/opt/fzf/shell/completion.zsh" ]]; then
    source "${HOMEBREW_PREFIX}/opt/fzf/shell/completion.zsh"
fi


### ---------------------------------------------------------------------------
### 11) CLI completion generation (cached)
### ---------------------------------------------------------------------------

if command -v gh >/dev/null 2>&1; then
    if [[ ! -f "${_ZSH_CLI_COMP_DIR}/_gh" ]]; then
        gh completion -s zsh > "${_ZSH_CLI_COMP_DIR}/_gh" 2>/dev/null
    fi
fi

if command -v stripe >/dev/null 2>&1; then
    if [[ ! -f "${_ZSH_CLI_COMP_DIR}/_stripe" ]]; then
        stripe completion --shell zsh > "${_ZSH_CLI_COMP_DIR}/_stripe" 2>/dev/null
    fi
fi


### ---------------------------------------------------------------------------
### 12) Aliases
### ---------------------------------------------------------------------------

function _alias_if_free() {
    local name="$1"
    local value="$2"

    if alias "${name}" >/dev/null 2>&1; then
        return 0
    fi

    if typeset -f "${name}" >/dev/null 2>&1; then
        return 0
    fi

    alias "${name}"="${value}"
}

# Navigation
_alias_if_free "l"   "ls -lah"
_alias_if_free "la"  "ls -A"
_alias_if_free "lt"  "ls -lahT"
_alias_if_free ".."  "cd .."
_alias_if_free "..." "cd ../.."

# Git
_alias_if_free "g"    "git"
_alias_if_free "gs"   "git status"
_alias_if_free "ga"   "git add"
_alias_if_free "gaa"  "git add -A"
_alias_if_free "gd"   "git diff"
_alias_if_free "gds"  "git diff --staged"
_alias_if_free "gcm"  "git commit -m"
_alias_if_free "gca"  "git commit --amend"
_alias_if_free "gl"   "git pull"
_alias_if_free "glr"  "git pull --rebase"
_alias_if_free "gp"   "git push"
_alias_if_free "gpf"  "git push --force-with-lease"
_alias_if_free "glog" "git log --oneline --decorate --graph --max-count=30"

# GitHub CLI
_alias_if_free "prc"  "gh pr create"
_alias_if_free "prv"  "gh pr view --web"
_alias_if_free "prl"  "gh pr list"
_alias_if_free "iss"  "gh issue list"

# ripgrep
_alias_if_free "ripgrep" "rg"

# 1Password
_alias_if_free "o"  "op"
_alias_if_free "ov" "op vault list"

# yazi
_alias_if_free "yy" "yazi"

# Network diagnostics
_alias_if_free "myip"  "curl -s https://ipinfo.io/ip"
_alias_if_free "myip6" "curl -6 -s https://ifconfig.me"
_alias_if_free "ports" "lsof -nP -iTCP -sTCP:LISTEN"


### ---------------------------------------------------------------------------
### 13) Productivity enhancements (only-if-installed)
### ---------------------------------------------------------------------------

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook zsh)"
fi

if command -v bat >/dev/null 2>&1; then
    alias cat="bat"
fi

if command -v fd >/dev/null 2>&1; then
    alias find="fd"
fi

if command -v rg >/dev/null 2>&1; then
    alias grep="rg"
fi

if command -v jq >/dev/null 2>&1; then
    alias j="jq"
fi

if command -v du >/dev/null 2>&1; then
    _alias_if_free "dus" "du -sh * | sort -h"
fi

if command -v tree >/dev/null 2>&1; then
    _alias_if_free "t" "tree -C -L 2"
fi


### ---------------------------------------------------------------------------
### 14) Local overrides (not managed by dotfiles)
### ---------------------------------------------------------------------------

if [[ -f "${HOME}/.zshrc.local" ]]; then
    source "${HOME}/.zshrc.local"
fi


### ---------------------------------------------------------------------------
### 15) Starship prompt
### ---------------------------------------------------------------------------

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi


### ---------------------------------------------------------------------------
### 16) Yazi: quit-to-cd integration
### ---------------------------------------------------------------------------

export YAZI_CONFIG_HOME="${HOME}/.config/yazi"

function y() {
    local tmp
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")" || return 1
    yazi --cwd-file="${tmp}" "${@}"

    if [[ -s "${tmp}" ]]; then
        local cwd
        cwd="$(cat "${tmp}")"
        if [[ -d "${cwd}" ]]; then
            cd "${cwd}" || true
        fi
    fi

    rm -f "${tmp}"
}

function yz() {
    local target
    target="$(zoxide query -i)" || return 1
    cd "${target}" || return 1
    y
}
