{ pkgs, inputs, ... }:
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  stylix = {
    enable = true;
    # Tracking nixpkgs-unstable + home-manager master: HM's version label (26.11)
    # leads nixpkgs-unstable's (26.05) until it bumps, which trips Stylix's release
    # heuristic. The inputs are date-aligned and compatible, so silence the check.
    enableReleaseChecks = false;
    base16Scheme = ../../../config/stylix/gruvbox-material-dark.yaml;
    polarity = "dark";

    # Solid dark background — desktop wallpaper is managed separately by awww.
    image = pkgs.runCommand "gruvbox-wallpaper" {
      nativeBuildInputs = [ pkgs.imagemagick ];
    } "magick -size 3840x2160 xc:'#282828' PNG:$out";

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      serif = {
        package = pkgs.liberation_ttf;
        name = "Liberation Serif";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      sizes = {
        applications = 11;
        desktop = 11;
        popups = 11;
        terminal = 13;
      };
    };

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };
  };

  home-manager.sharedModules = [
    {
      # Keep manual themes for apps with complex non-colour config.
      stylix.targets = {
        bat.enable = false;
        kitty.enable = false;
        tmux.enable = false;
        starship.enable = false;
        btop.enable = false;
        waybar.enable = false;
        hyprland.enable = false;
        mpv.enable = false;
        vscode.enable = false;
        zed.enable = false;
      };
    }
  ];
}
