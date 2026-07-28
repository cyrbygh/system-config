{ pkgs, ... }:

{
  programs.git = {
    enable = true;
    user = {
      name = "Kerb Byqvist";
      email = "cyrbygh@users.noreply.github.com";
    };
    ignores = [
      ".idea/"
      ".DS_Store"
      "venv/"
      "__pycache__"
      "*.egg-info"
      ".claude/"
    ];
    settings = {
      url."git@github.com:cyrbygh/".insteadOf = "https://github.com/cyrbygh/";
      commit.gpgsign = false;
    };
  };

  programs.zsh = {
    enable = true;
    autocd = true;
    defaultKeymap = "viins";
    history = {
      size = 999999999;
      save = 999999999;
      share = true;
      ignoreDups = true;
    };
    shellAliases = {
      # git
      ga    = "git add";
      gr    = "git rm -r";
      gd    = "git diff";
      gpl   = "git pull --no-rebase origin $(git branch --show-current)";
      gps   = "git push origin $(git branch --show-current)";
      gst   = "git status";
      gm    = "git checkout main";
      gmu   = "_b=$(git branch --show-current); gm; gpl; git checkout \${_b}";
      gmub  = "gmu; gm; git checkout -b";
      gb    = "git branch";
      gbm   = "git branch -m";
      gbd   = "git branch -D";
      gl    = "git log";
      gcm   = "git commit -m ";
      gca   = "git commit --amend";
      # misc
      dd    = "dd status=progress ";
      tmux  = "tmux -u";
    };
    initContent = ''
      if [[ "$(uname -s)" =~ Darwin ]]; then
        alias ls='ls -G'
      else
        alias ls='ls --color=auto'
      fi
      alias lsa='ls -a'

      autoload -U zmv

      bindkey '^R' history-incremental-search-backward

      setopt extended_glob
      setopt auto_pushd
      setopt pushd_silent

      function git_prompt_info() {
        local branch=$(git branch --show-current 2>/dev/null)
        if [[ -z "''${branch}" ]]; then
          branch=$(git rev-parse --short HEAD 2>/dev/null)
          [[ -n "''${branch}" ]] || return
        fi
        local dirty=""
        [[ -n $(git status --porcelain 2>/dev/null) ]] && dirty="%F{red} *%f"
        echo "%F{green}%B[''${branch}%f''${dirty}%F{green}]%b%f"
      }

      setopt prompt_subst
      PROMPT='%F{yellow}%B%n%b%F{white}%B:%m%b%f%F{white}@%T %F{209}[%~]%f
%F{green}%B→%b%f '
      RPROMPT='$(git_prompt_info)'

      export EDITOR="vim"
      export PATH="$HOME/.local/bin:$PATH"
    '';
  };

  programs.tmux = {
    enable = true;
    extraConfig = ''
      set-option -g default-shell ${pkgs.zsh}/bin/zsh
      set -g default-terminal "screen-256color"
      set -g prefix C-a
      unbind C-b
      set -sg escape-time 1
      set-option -g base-index 1
      setw -g pane-base-index 1
      set -g mouse on
      bind r source-file ~/.tmux.conf \; display "Reloaded!"
      bind | split-window -h
      bind - split-window -v
      bind b setw synchronize-panes
    '';
  };

  programs.vim = {
    enable = true;
    extraConfig = ''
      set ruler
      set number
      syntax on
    '';
  };
}
