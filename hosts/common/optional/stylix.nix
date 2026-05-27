{ pkgs, inputs, ... }:
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  stylix = {
    enable = true;
    base16Scheme = ../../../config/stylix/gruvbox-material-dark.yaml;
    polarity = "dark";

    # Solid dark background — desktop wallpaper is managed separately by swww.
    image = pkgs.runCommand "gruvbox-wallpaper" {
      nativeBuildInputs = [ pkgs.imagemagick ];
    } "convert -size 3840x2160 xc:'#282828' $out";

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
        package = pkgs.noto-fonts-emoji;
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
      stylix.targets.tmux.enable = false;
      stylix.targets.starship.enable = false;
      stylix.targets.btop.enable = false;
      stylix.targets.waybar.enable = false;
      stylix.targets.hyprland.enable = false;
    }
  ];
}
