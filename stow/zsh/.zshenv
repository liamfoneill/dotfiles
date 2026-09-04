. "$HOME/.cargo/env"

# Added by tempoup installer
. "$HOME/.tempo/env"

# The Stripe `claude` wrapper prepends its own --permission-mode from this var,
# ahead of whatever the VS Code extension passes, and the first flag wins.
# Unset, it defaults to `auto`, which prompts for non-trivial Bash commands.
export STRIPE_CLAUDE_PERMISSION_MODE=bypassPermissions
