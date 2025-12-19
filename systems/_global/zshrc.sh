export EDITOR="vim"
export PATH="${HOME}/.local/bin:${PATH}"

# History settings
export HISTFILE=~/.zsh_history
export HISTSIZE=999999999
export SAVEHIST=${HISTSIZE}

setopt share_history         # Share command history between all sessions.
setopt auto_cd               # Try interpreting the command as a directory if it doesn't exist.
setopt hist_ignore_dups      # Don't record duplicate commands.
setopt extended_glob         # Enable advanced globbing patterns like **/* ^file ~pattern.
setopt auto_pushd            # Make cd push directories to directory stack.
setopt pushd_silent          # Do not print the directory when calling pushd.

# Module for batch renaming files.
autoload -U zmv

bindkey -v # Use vim key bindings.
bindkey '^R' history-incremental-search-backward

function git_prompt_info() {
  local branch=$(git branch --show-current 2>/dev/null)
  [[ -n "${branch}" ]] || return

  local dirty=""
  [[ -n $(git status --porcelain 2>/dev/null) ]] && dirty="%F{red} *%f"

  echo "%F{green}%B[${branch}${dirty}]%b%f"
}

setopt prompt_subst  # allow zsh evaluation and expansion within the prompt string
PROMPT='%F{yellow}%B%n%b%F{white}%B:%m%b%f%F{white}@%T %F{209}[%~]%f
%F{green}%B→%b%f '
RPROMPT='$(git_prompt_info)'

# Load any extra custom configuration for this machine.
if [[ -d ~/.env ]]; then
  find -L ~/.env -type f | while read -r file; do
    source "${file}"
  done
fi
