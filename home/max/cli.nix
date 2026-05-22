{ pkgs, config, ... }:
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

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/bin"
  ];

  programs.zsh.dotDir = "${config.xdg.configHome}/zsh";

  programs.bat = {
    enable = true;
    config = {
      theme = "gruvbox-dark";
      pager = "less -RF";
      italic-text = "always";
    };
  };

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

  programs.ripgrep = {
    enable = true;
    arguments = [
      "--smart-case"
      "--follow"
      "--hidden"
      "--glob=!.git"
    ];
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      addKeysToAgent = "yes";
      serverAliveInterval = 60;
      serverAliveCountMax = 3;
      extraOptions.IdentityAgent = "/run/user/1000/gnupg/S.gpg-agent.ssh";
    };
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  services.gnome-keyring.enable = true;
}
