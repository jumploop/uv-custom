#!/bin/sh
#
# UV + Conda/Mamba Environment Hook Injector for macOS & Linux
#
# This script intelligently detects installed shells (Bash, Zsh, Fish, Elvish)
# and injects a hook to sync UV_PROJECT_ENVIRONMENT with the active Conda/Mamba
# environment. It is idempotent and safe to run multiple times.
#

# --- Helper Functions ---
say() {
    echo "› $1"
}

inject_code() {
    local config_file="$1"
    local marker="$2"
    local code_block="$3"
    local shell_name="$4"

    # Ensure the parent directory exists before writing.
    mkdir -p "$(dirname "$config_file")"
    # Ensure the config file itself exists.
    touch "$config_file"

    if grep -qF -- "$marker" "$config_file" 2>/dev/null; then
        say "$shell_name hook already exists in $config_file. Skipping."
    else
        say "Injecting $shell_name hook into $config_file..."
        printf '\n%s\n' "$code_block" >> "$config_file"
        say "Successfully injected hook for $shell_name."
    fi
}

# --- Shell-Specific Setups ---
setup_bash() {
    if ! command -v bash >/dev/null 2>&1; then return; fi
    say "Bash detected. Setting up hook..."
    local config_file="$HOME/.bashrc"
    local marker="# UV-CONDA-HOOK-BASH-START"
    local code_block=$(cat <<'EOF'
# UV-CONDA-HOOK-BASH-START
_sync_mamba_uv_env() {
  if [ -n "$CONDA_PREFIX" ]; then
    if [ -z "$UV_PROJECT_ENVIRONMENT" ] || [ "$UV_PROJECT_ENVIRONMENT" != "$CONDA_PREFIX" ]; then
      export UV_PROJECT_ENVIRONMENT="$CONDA_PREFIX"
    fi
  else
    if [ -n "$UV_PROJECT_ENVIRONMENT" ]; then
      unset UV_PROJECT_ENVIRONMENT
    fi
  fi
}
if [[ ! "$PROMPT_COMMAND" =~ _sync_mamba_uv_env ]]; then
  PROMPT_COMMAND="_sync_mamba_uv_env;${PROMPT_COMMAND}"
fi
# UV-CONDA-HOOK-BASH-END
EOF
)
    inject_code "$config_file" "$marker" "$code_block" "Bash"
}

setup_zsh() {
    if ! command -v zsh >/dev/null 2>&1; then return; fi
    say "Zsh detected. Setting up hook..."
    local config_file="$HOME/.zshrc"
    local marker="# UV-CONDA-HOOK-ZSH-START"
    local code_block=$(cat <<'EOF'
# UV-CONDA-HOOK-ZSH-START
_sync_mamba_uv_env() {
  if [ -n "$CONDA_PREFIX" ]; then
    if [ -z "$UV_PROJECT_ENVIRONMENT" ] || [ "$UV_PROJECT_ENVIRONMENT" != "$CONDA_PREFIX" ]; then
      export UV_PROJECT_ENVIRONMENT="$CONDA_PREFIX"
    fi
  else
    if [ -n "$UV_PROJECT_ENVIRONMENT" ]; then
      unset UV_PROJECT_ENVIRONMENT
    fi
  fi
}
if [[ ! " ${precmd_functions[@]} " =~ " _sync_mamba_uv_env " ]]; then
  precmd_functions+=(_sync_mamba_uv_env)
fi
# UV-CONDA-HOOK-ZSH-END
EOF
)
    inject_code "$config_file" "$marker" "$code_block" "Zsh"
}

setup_fish() {
    if ! command -v fish >/dev/null 2>&1; then return; fi
    say "Fish detected. Setting up hook..."
    local config_file="$HOME/.config/fish/config.fish"
    local marker="# UV-CONDA-HOOK-FISH-START"
    local code_block=$(cat <<'EOF'
# UV-CONDA-HOOK-FISH-START
function _sync_mamba_uv_env --on-event fish_preexec
    if set -q CONDA_PREFIX
        if not set -q UV_PROJECT_ENVIRONMENT; or test "$UV_PROJECT_ENVIRONMENT" != "$CONDA_PREFIX"
            set -gx UV_PROJECT_ENVIRONMENT "$CONDA_PREFIX"
        end
    else
        if set -q UV_PROJECT_ENVIRONMENT
            set -e UV_PROJECT_ENVIRONMENT
        end
    end
end
# UV-CONDA-HOOK-FISH-END
EOF
)
    inject_code "$config_file" "$marker" "$code_block" "Fish"
}

setup_elvish() {
    if ! command -v elvish >/dev/null 2>&1; then return; fi
    say "Elvish detected. Setting up hook..."
    local config_file="$HOME/.config/elvish/rc.elv"
    local marker="# UV-CONDA-HOOK-ELVISH-START"
    local code_block=$(cat <<'EOF'
# UV-CONDA-HOOK-ELVISH-START
set edit:before-prompt = [ $@edit:before-prompt {
    if (has-env CONDA_PREFIX) {
        if (not (has-env UV_PROJECT_ENVIRONMENT)) or (not (== $E:UV_PROJECT_ENVIRONMENT $E:CONDA_PREFIX)) {
            set-env UV_PROJECT_ENVIRONMENT $E:CONDA_PREFIX
        }
    } else {
        if (has-env UV_PROJECT_ENVIRONMENT) {
            unset-env UV_PROJECT_ENVIRONMENT
        }
    }
} ]
# UV-CONDA-HOOK-ELVISH-END
EOF
)
    inject_code "$config_file" "$marker" "$code_block" "Elvish"
}

# --- Main Execution ---
echo "--- Setting up UV + Conda/Mamba Hooks for macOS/Linux ---"
setup_bash
setup_zsh
setup_fish
setup_elvish
echo "---------------------------------------------------------"
echo "Setup complete. Please restart your shell(s) to apply changes."