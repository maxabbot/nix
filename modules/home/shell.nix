# modules/home/shell.nix — Zsh, Starship, fzf, zoxide, tmux, and shell aliases/functions.
{
  config,
  lib,
  ...
}:
let
  palette = import ../../config/stylix/palette.nix;
in
{
  programs = {
    # ── Zsh ───────────────────────────────────────────────────────────────────────
    zsh = {
      enable = true;

      history = {
        size = 50000;
        save = 50000;
        path = "${config.xdg.dataHome}/zsh/history";
        extended = true;
        ignoreDups = true;
        ignoreSpace = true;
        share = true;
        expireDuplicatesFirst = true;
      };

      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      historySubstringSearch.enable = true;

      sessionVariables = {
        EDITOR = "zed --wait";
        VISUAL = "zed --wait";
        LANG = "en_US.UTF-8";
        LC_ALL = "en_US.UTF-8";
        ARCHFLAGS = "-arch x86_64";
        MANPAGER = "less -R --use-color -Dd+r -Du+b";
        BAT_PAGER = "less -RF";
        CARGO_HOME = "$HOME/.cargo";
        RUSTUP_HOME = "$HOME/.rustup";
        GOPATH = "$HOME/go";
      };

      shellAliases = {
        # Bat
        cat = "bat --paging=never";
        less = "bat --paging=always";

        # eza (modern ls)
        ls = "eza --color=always --group-directories-first --icons";
        ll = "eza -la --color=always --group-directories-first --icons --git";
        la = "eza -a --color=always --group-directories-first --icons";
        l = "eza -la --color=always --group-directories-first --icons --git";
        lt = "eza -aT --color=always --group-directories-first --icons --level=2";
        "l." = "eza -a --color=always --group-directories-first --icons | grep '\\.'";

        # General
        ".." = "cd ..";
        "..." = "cd ../..";
        "...." = "cd ../../..";
        grep = "grep --color=auto";
        df = "df -h";
        du = "du -h";
        free = "free -h";

        # Safety nets
        rm = "rm -i";
        cp = "cp -i";
        mv = "mv -i";

        # NixOS package management (replaces pacman/yay)
        nixup = "nh os switch /etc/nixos";
        nixsrch = "nix search nixpkgs";
        nixshell = "nix shell nixpkgs#";
        nixtmp = "nix-shell -p";
        gcclean = "sudo nix-collect-garbage -d && sudo nix store optimise";
        flkupd = "nix flake update";

        # System management (systemd)
        srestart = "sudo systemctl restart";
        sstatus = "sudo systemctl status";
        senable = "sudo systemctl enable";
        sdisable = "sudo systemctl disable";
        jctl = "journalctl -xe";

        # Git
        g = "git";
        gs = "git status";
        ga = "git add";
        gaa = "git add --all";
        gc = "git commit -v";
        gcm = "git commit -m";
        gp = "git push";
        gpl = "git pull";
        gd = "git diff";
        gl = "git log --oneline --graph --decorate";
        gco = "git checkout";
        gb = "git branch";
        gba = "git branch -a";

        # Podman (docker-compatible aliases)
        d = "podman";
        p = "podman";
        dc = "podman-compose";
        dps = "podman ps";
        dpsa = "podman ps -a";
        dim = "podman images";
        dex = "podman exec -it";
        dlog = "podman logs -f";

        # Python
        py = "python";
        py3 = "python3";
        venv = "python -m venv";
        activate = "source venv/bin/activate";

        # Rust / Cargo
        c = "cargo";
        cb = "cargo build";
        cr = "cargo run";
        ct = "cargo test";
        cc = "cargo check";
        cu = "cargo update";

        # Node / npm
        nr = "npm run";
        ni = "npm install";
        nid = "npm install --save-dev";
        nt = "npm test";
        nb = "npm run build";
        ns = "npm start";

        # App shortcuts
        zed = "zeditor";
        zen = "zen-beta";
        chrome = "google-chrome-stable";

        # Ambient / weather (no install — hits wttr.in)
        wttr = "curl -s 'wttr.in/?F'";
        weather = "curl -s 'wttr.in/?F'";
        spt = "spotify_player";
      };

      initContent = ''
        # ── Key bindings ────────────────────────────────────────────────────────
        bindkey '^[[A'  history-substring-search-up
        bindkey '^[[B'  history-substring-search-down
        bindkey '^[[H'  beginning-of-line
        bindkey '^[[F'  end-of-line
        bindkey '^[[3~' delete-char

        # ESC-ESC to prepend/remove sudo
        sudo-command-line() {
          [[ -z $BUFFER ]] && zle up-history
          if [[ $BUFFER == sudo\ * ]]; then
            LBUFFER="''${LBUFFER#sudo }"
          else
            LBUFFER="sudo $LBUFFER"
          fi
        }
        zle -N sudo-command-line
        bindkey '\e\e' sudo-command-line

        # CTRL-f — tmux-sessionizer
        bindkey -s '^f' 'tmux-sessionizer\n'

        # ── PATH ─────────────────────────────────────────────────────────────────
        export PATH="$HOME/.local/bin:$HOME/bin:$HOME/.cargo/bin:$GOPATH/bin:$PATH"

        # ── Rust ─────────────────────────────────────────────────────────────────
        [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

        # ── mise (universal version manager) ─────────────────────────────────────
        command -v mise &>/dev/null && eval "$(mise activate zsh)"

        # ── fzf key-bindings (provided by fzf NixOS module) ──────────────────────
        [[ -f /run/current-system/sw/share/fzf/key-bindings.zsh ]] &&
          source /run/current-system/sw/share/fzf/key-bindings.zsh
        [[ -f /run/current-system/sw/share/fzf/completion.zsh ]] &&
          source /run/current-system/sw/share/fzf/completion.zsh

        # ── kubectl completions ───────────────────────────────────────────────────
        command -v kubectl &>/dev/null && source <(kubectl completion zsh)

        # ── Shell functions ───────────────────────────────────────────────────────
        mkcd() { mkdir -p "$1" && cd "$1"; }

        extract() {
          if [ -f "$1" ]; then
            case "$1" in
              *.tar.bz2)  tar xjf "$1"    ;;
              *.tar.gz)   tar xzf "$1"    ;;
              *.bz2)      bunzip2 "$1"    ;;
              *.rar)      unrar x "$1"    ;;
              *.gz)       gunzip "$1"     ;;
              *.tar)      tar xf "$1"     ;;
              *.tgz)      tar xzf "$1"    ;;
              *.zip)      unzip "$1"      ;;
              *.Z)        uncompress "$1" ;;
              *.7z)       7z x "$1"       ;;
              *)          echo "'$1' cannot be extracted via extract()" ;;
            esac
          else
            echo "'$1' is not a valid file"
          fi
        }

        qfind()  { find . -iname "*$1*"; }
        psgrep() { ps aux | grep -v grep | grep -i -e VSZ -e "$1"; }
        gcl()    { git clone "$1" && cd "$(basename "$1" .git)"; }
        mkvenv() { python -m venv "''${1:-.venv}" && source "''${1:-.venv}/bin/activate"; }
        serve()  { python -m http.server "''${1:-8000}"; }
        dclean() { podman system prune -af --volumes; }

        sysup() {
          nh os switch /etc/nixos
          command -v rustup &>/dev/null && rustup update
        }

        # Build first, then decide how to apply. If the new generation swaps out
        # systemd, a live `switch` re-execs the manager and restarts the Wayland
        # session (Hyprland dies, desktop freezes) — so stage it for next boot
        # instead. Otherwise switch live as usual.
        nixup-safe() {
          local flake=/etc/nixos host new_top cur_sd new_sd
          host=$(hostname)
          echo ":: building configuration for $host …"
          new_top=$(nix build --no-link --print-out-paths \
            "$flake#nixosConfigurations.$host.config.system.build.toplevel") || {
            echo ":: build failed — nothing applied"; return 1;
          }
          cur_sd=$(readlink -f /run/current-system/systemd)
          new_sd=$(readlink -f "$new_top/systemd")
          if [[ "$cur_sd" != "$new_sd" ]]; then
            echo ":: systemd changes under the live session:"
            echo "     $(basename "$cur_sd")  ->  $(basename "$new_sd")"
            echo ":: a live switch would re-exec systemd and restart Hyprland (freeze risk)."
            echo ":: staging for next boot instead of switching live."
            sudo nixos-rebuild boot --flake "$flake#$host" || return 1
            echo ":: staged. reboot to apply:  systemctl reboot"
          else
            echo ":: systemd unchanged — live switch is safe."
            nh os switch "$flake"
          fi
        }

        copypath() { print -n "''${1:-$PWD}" | wl-copy && echo "Copied: ''${1:-$PWD}"; }
        copyfile() { wl-copy < "$1" && echo "Copied: $1"; }

        if command -v fzf &>/dev/null; then
          fcd() {
            local dir
            dir=$(find ''${1:-.} -type d 2>/dev/null | fzf +m) && cd "$dir"
          }
        fi

        # ── Local overrides ───────────────────────────────────────────────────────
        [[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
      '';
    };

    # ── Starship prompt ────────────────────────────────────────────────────────────
    starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        "$schema" = "https://starship.rs/config-schema.json";

        format = lib.concatStrings [
          "[](${palette.bg0})"
          "$os"
          "$username"
          "[](bg:${palette.bg1} fg:${palette.bg0})"
          "$directory"
          "[](fg:${palette.bg1} bg:${palette.bg2})"
          "$git_branch"
          "$git_status"
          "[](fg:${palette.bg2} bg:${palette.bg3})"
          "$python$nodejs$rust$golang$java"
          "[](fg:${palette.bg3} bg:${palette.bg0})"
          "$time"
          "[ ](fg:${palette.bg0})"
          "\n$character"
        ];

        os = {
          disabled = false;
          style = "bg:${palette.bg0} fg:${palette.purple}";
        };
        username = {
          show_always = true;
          style_user = "bg:${palette.bg0} fg:${palette.fg}";
          style_root = "bg:${palette.bg0} fg:${palette.red}";
          format = "[$user ]($style)";
          disabled = false;
        };
        directory = {
          style = "bg:${palette.bg1} fg:${palette.blue}";
          format = "[ $path ]($style)";
          truncation_length = 3;
          truncation_symbol = "…/";
          substitutions = {
            "Documents" = "󰈙 ";
            "Downloads" = " ";
            "Music" = "󰝚 ";
            "Pictures" = " ";
            "Projects" = "󰲋 ";
            ".config" = " ";
          };
        };
        git_branch = {
          symbol = "";
          style = "bg:${palette.bg2} fg:${palette.green}";
          format = "[ $symbol $branch ]($style)";
        };
        git_status = {
          style = "bg:${palette.bg2} fg:${palette.red}";
          format = "[$all_status$ahead_behind ]($style)";
          conflicted = "⚡";
          ahead = "⇡\${count}";
          behind = "⇣\${count}";
          diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
          up_to_date = "✓";
          untracked = "?";
          modified = "!";
          staged = "+";
          renamed = "»";
          deleted = "✘";
        };
        python = {
          symbol = "";
          style = "bg:${palette.bg3} fg:${palette.yellow}";
          format = "[ $symbol ($version) ]($style)";
        };
        nodejs = {
          symbol = "";
          style = "bg:${palette.bg3} fg:${palette.green}";
          format = "[ $symbol ($version) ]($style)";
        };
        rust = {
          symbol = "";
          style = "bg:${palette.bg3} fg:${palette.orange}";
          format = "[ $symbol ($version) ]($style)";
        };
        golang = {
          symbol = "";
          style = "bg:${palette.bg3} fg:${palette.aqua}";
          format = "[ $symbol ($version) ]($style)";
        };
        java = {
          symbol = "";
          style = "bg:${palette.bg3} fg:${palette.red}";
          format = "[ $symbol ($version) ]($style)";
        };
        time = {
          disabled = false;
          time_format = "%H:%M";
          style = "bg:${palette.bg0} fg:${palette.bg4}";
          format = "[ 󰥔 $time ]($style)";
        };
        character = {
          success_symbol = "[❯](bold fg:${palette.green})";
          error_symbol = "[❯](bold fg:${palette.red})";
          vimcmd_symbol = "[❮](bold fg:${palette.purple})";
        };
      };
    };

    # ── fzf ────────────────────────────────────────────────────────────────────────
    fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = "fd --type f --hidden --follow --exclude .git";
      changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
      fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
      defaultOptions = [
        "--height 40%"
        "--border rounded"
        "--multi"
      ];
    };

    # ── zoxide (better cd) ─────────────────────────────────────────────────────────
    zoxide = {
      enable = true;
      enableZshIntegration = true;
      options = [ "--cmd cd" ];
    };

    # ── atuin (SQLite-backed shell history, fuzzy Ctrl-R) ──────────────────────────
    atuin = {
      enable = true;
      enableZshIntegration = true;
      # Keep the existing up-arrow history-substring-search binding; atuin takes Ctrl-R.
      flags = [ "--disable-up-arrow" ];
      settings = {
        style = "compact";
        inline_height = 25;
        show_preview = true;
        update_check = false;
      };
    };

    # ── tmux ───────────────────────────────────────────────────────────────────────
    tmux = {
      enable = true;
      prefix = "C-a";
      mouse = true;
      historyLimit = 50000;
      baseIndex = 1;
      keyMode = "vi";
      terminal = "tmux-256color";
      escapeTime = 0;
      focusEvents = true;

      extraConfig = ''
        set -ga terminal-overrides ",xterm-256color:Tc"
        setw -g pane-base-index 1
        set  -g renumber-windows on
        set  -g set-clipboard on

        # Vim-style copy mode
        bind -T copy-mode-vi v   send -X begin-selection
        bind -T copy-mode-vi y   send -X copy-selection-and-cancel
        bind -T copy-mode-vi C-v send -X rectangle-toggle

        # Intuitive splits (open in current path)
        unbind '"'
        unbind %
        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"
        bind c new-window      -c "#{pane_current_path}"

        # Vim-style pane navigation
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R

        # Pane resize
        bind -r H resize-pane -L 5
        bind -r J resize-pane -D 5
        bind -r K resize-pane -U 5
        bind -r L resize-pane -R 5

        # Sessionizer
        bind   f run-shell "tmux-sessionizer"
        bind C-f run-shell "tmux-sessionizer"

        # Reload config
        bind r source-file ~/.tmux.conf \; display "Config reloaded"

        # ── Theme — Gruvbox Material Dark ─────────────────────────────────────────
        set -g status on
        set -g status-interval  5
        set -g status-position  bottom
        set -g status-justify   left
        set -g status-style     "bg=${palette.bg0}"
        set -g status-left-length  80
        set -g status-right-length 150

        set -g status-left \
          "#[fg=${palette.bg0},bg=${palette.yellow},bold] #S #[fg=${palette.yellow},bg=${palette.bg1},nobold]#[fg=${palette.fg},bg=${palette.bg1}] #{b:pane_current_path} #[fg=${palette.bg1},bg=${palette.bg0}]"
        set -g status-right \
          "#[fg=${palette.bg1},bg=${palette.bg0}]#[fg=${palette.fg},bg=${palette.bg1}] %H:%M #[fg=${palette.bg2},bg=${palette.bg1}]#[fg=${palette.fg},bg=${palette.bg2}] %d %b #[fg=${palette.blue},bg=${palette.bg2}]#[fg=${palette.bg0},bg=${palette.blue},bold] #h "

        set -g window-status-format \
          "#[fg=${palette.bg0},bg=${palette.bg1}]#[fg=${palette.fg},bg=${palette.bg1}] #I  #W #[fg=${palette.bg1},bg=${palette.bg0}]"
        set -g window-status-current-format \
          "#[fg=${palette.bg0},bg=${palette.yellow}]#[fg=${palette.bg0},bg=${palette.yellow},bold] #I  #W #[fg=${palette.yellow},bg=${palette.bg0}]"
        set -g window-status-separator ""

        set -g pane-border-style        "fg=${palette.bg2}"
        set -g pane-active-border-style "fg=${palette.blue}"
        set -g message-style            "bg=${palette.bg1},fg=${palette.fg}"
        set -g message-command-style    "bg=${palette.bg1},fg=${palette.fg}"
        set -g mode-style               "bg=${palette.yellow},fg=${palette.bg0}"
      '';
    };
  };
}
