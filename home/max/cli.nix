{ config, ... }:
{
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      setSessionVariables = true;
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

  # Prepended to PATH, in this order. ~/go is GOPATH (shell.nix).
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/bin"
    "$HOME/.cargo/bin"
    "$HOME/go/bin"
  ];

  programs = {
    zsh.dotDir = "${config.xdg.configHome}/zsh";
    bat = {
      enable = true;
      config = {
        theme = "gruvbox-dark";
        pager = "less -RF";
        italic-text = "always";
      };
    };
    eza = {
      enable = true;
      enableZshIntegration = true;
      icons = "auto";
      git = true;
      extraOptions = [
        "--group-directories-first"
        "--color=always"
      ];
    };
    ripgrep = {
      enable = true;
      arguments = [
        "--smart-case"
        "--follow"
        "--hidden"
        "--glob=!.git"
      ];
    };
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings."*" = {
        AddKeysToAgent = "yes";
        ServerAliveInterval = 60;
        ServerAliveCountMax = 3;
        # Force gpg-agent even if something else (e.g. gcr-ssh-agent) claims
        # SSH_AUTH_SOCK. ssh expands env vars here, so no hardcoded UID needed.
        IdentityAgent = "\${XDG_RUNTIME_DIR}/gnupg/S.gpg-agent.ssh";
      };
    };
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };

  # No services.gnome-keyring here: base.nix's services.gnome.gnome-keyring
  # starts the daemon from PAM at login (unlocking the keyring with the login
  # password), and HM's unit only started a second one alongside it.
}
