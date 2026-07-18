{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  palette = import ../../../config/stylix/palette.nix;
in
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  # stylix's kmscon module sets services.kmscon.config which was removed in
  # NixOS 26.05 (renamed to extraConfig). Disable the module entirely.
  disabledModules = [ "${inputs.stylix}/modules/kmscon/nixos.nix" ];

  stylix = {
    enable = true;
    # Stylix tracks master (no release-26.05 branch yet) while the system is on
    # stable nixpkgs/HM 26.05 — silence the resulting version-mismatch check.
    enableReleaseChecks = false;
    # base16 scheme derived from the shared palette (config/stylix/palette.nix).
    base16Scheme = {
      scheme = "Gruvbox Material Dark";
      author = "Max Abbot (derived from sainnhe/gruvbox-material)";
      variant = "dark";
    }
    // lib.mapAttrs (_: lib.removePrefix "#") {
      base00 = palette.bg0; # hard background
      base01 = palette.bg1; # status bar / darker bg
      base02 = palette.bg2; # selection background
      base03 = palette.bg3; # mid background
      base04 = palette.gray; # comments / dim fg
      base05 = palette.fg; # default foreground
      base06 = palette.fgBright; # lighter foreground
      base07 = palette.fgBrighter; # lightest foreground
      base08 = palette.red;
      base09 = palette.orange;
      base0A = palette.yellow;
      base0B = palette.green;
      base0C = palette.aqua;
      base0D = palette.blue;
      base0E = palette.purple;
      base0F = palette.brown;
    };
    polarity = "dark";

    # Solid dark background — desktop wallpaper is managed separately by awww.
    # 1×1 px is enough: anything that displays it scales it to a solid fill.
    image = pkgs.runCommand "gruvbox-wallpaper" {
      nativeBuildInputs = [ pkgs.imagemagick ];
    } "magick -size 1x1 xc:'${palette.bg0}' PNG:$out";

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
      # HM-level stylix module has its own release check — silence it too
      # (Stylix master on stable HM 26.05; see the NixOS-level note above).
      stylix.enableReleaseChecks = false;

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
