# home/max/default.nix — Home Manager configuration for user "max".
# Receives specialArgs from the host: machineType, compositor, monitors, git, location.
{
  pkgs,
  lib,
  machineType,
  compositor,
  monitors,
  git,
  location,
  inputs,
  ...
}:
{
  imports = [
    ../../modules/home/default.nix
  ];

  # ── HM options passed from host ──────────────────────────────────────────────
  custom.hm.compositor = compositor;
  custom.hm.monitors = monitors;

  # ── Basic HM settings ────────────────────────────────────────────────────────
  home = {
    username = "max";
    homeDirectory = "/home/max";
    stateVersion = "24.11";

    packages = with pkgs; [
      # Communication (always present for this user)
      thunderbird
      element-desktop

      # Dev tools
      jq
      yq-go
      gh
      mkcert
      httpie

      # File transfer
      rsync

      # Misc CLI
      ffmpeg-full
      imagemagick

      # NixOS-specific helpers
      nix-tree
      nix-diff
      nixpkgs-review
    ];
  };

  # ── Git ───────────────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    userName = git.name;
    userEmail = git.email;

    delta = {
      enable = true;
      options = {
        navigate = true;
        light = false;
        side-by-side = true;
        line-numbers = true;
        syntax-theme = "gruvbox-dark";
        features = "gruvbox-material";
        # Plus/minus line colours
        "plus-style" = ''syntax "#1e4920"'';
        "minus-style" = ''syntax "#4a1020"'';
        "file-style" = ''bold "#89b4fa"'';
        "hunk-header-style" = "file line-number syntax";
      };
    };

    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      fetch.prune = true;
      merge.conflictstyle = "zdiff3";
      diff.colorMoved = "default";
      rebase.autoStash = true;
      rerere.enabled = true;
      column.ui = "auto";
      branch.sort = "-committerdate";
      core = {
        autocrlf = "input";
        editor = "hx";
        pager = "delta";
        whitespace = "fix,-indent-with-non-tab,trailing-space,cr-at-eol";
      };
      # interactive.diffFilter is set automatically by programs.delta
    };

    aliases = {
      st = "status -sb";
      co = "checkout";
      br = "branch -vv";
      lg = "log --oneline --graph --decorate --all";
      last = "log -1 HEAD --stat";
      undo = "reset HEAD~1 --mixed";
      unstage = "reset HEAD --";
      wip = "!git add -A && git commit -m 'wip'";
    };
  };

  # ── Gammastep (night light — Wayland only, not on headless) ───────────────────
  services.gammastep = lib.mkIf (machineType != "server") {
    enable = true;
    provider = "manual";
    latitude = location.latitude;
    longitude = location.longitude;
    temperature = {
      day = 6500;
      night = 3500;
    };
  };

  # ── XDG directories ───────────────────────────────────────────────────────────
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "$HOME/Desktop";
      documents = "$HOME/Documents";
      download = "$HOME/Downloads";
      music = "$HOME/Music";
      pictures = "$HOME/Pictures";
      publicShare = "$HOME/Public";
      templates = "$HOME/Templates";
      videos = "$HOME/Videos";
    };
  };

  # ── SSH ────────────────────────────────────────────────────────────────────────
  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
    serverAliveInterval = 60;
    serverAliveCountMax = 3;
    extraConfig = ''
      IdentityAgent /run/user/1000/gnupg/S.gpg-agent.ssh
    '';
  };

  # Ensure gnome-keyring is running for SSH keys
  services.gnome-keyring.enable = true;

  # ── Direnv ────────────────────────────────────────────────────────────────────
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # ── Bat (better cat) ──────────────────────────────────────────────────────────
  programs.bat = {
    enable = true;
    config = {
      theme = "gruvbox-dark";
      pager = "less -RF";
      italic-text = "always";
    };
  };

  # ── Eza (modern ls) ───────────────────────────────────────────────────────────
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = "auto";
    git = true;
    extraOptions = [
      "--group-directories-first"
      "--color=always"
    ];
  };

  # ── Ripgrep ───────────────────────────────────────────────────────────────────
  programs.ripgrep = {
    enable = true;
    arguments = [
      "--smart-case"
      "--follow"
      "--hidden"
      "--glob=!.git"
    ];
  };

  # ── Allow HM to manage the login shell ────────────────────────────────────────
  programs.zsh.enable = true;
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/bin"
  ];
}
