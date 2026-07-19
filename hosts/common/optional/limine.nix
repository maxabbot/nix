# hosts/common/optional/limine.nix — Limine boot manager (replaces systemd-boot).
# Graphical boot menu themed from the shared Gruvbox Material palette, with the
# wallpaper centred over a matching backdrop (image is 3480x2160, so centering
# avoids stretch distortion on 16:9 panels).
#
# Secure Boot: once sbctl keys are created and enrolled (see lanzaboote.nix for
# the enrollment steps), set `boot.loader.limine.secureBoot.enable = true` here
# instead of importing lanzaboote — Limine signs with the same sbctl keys.
{ lib, ... }:
let
  palette = import ../../../config/stylix/palette.nix;
  c = name: lib.removePrefix "#" palette.${name};
  colors = names: lib.concatMapStringsSep ";" c names;
in
{
  # Hosts importing this file must not enable systemd-boot; force it off so a
  # leftover `systemd-boot.enable = true` can't leave two loaders fighting.
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.loader.limine = {
    enable = true;
    # Cap the boot menu so old generations don't accumulate as stale entries.
    maxGenerations = 10;

    style = {
      wallpapers = [ ../../../config/limine/gruvbox-rainbow-nix.png ];
      wallpaperStyle = "centered";
      backdrop = c "bg0Hard";

      interface = {
        branding = "NixOS";
        brandingColor = c "yellow";
        helpColor = c "gray";
        helpColorBright = c "fgBright";
      };

      # Terminal slots are black,red,green,brown,blue,magenta,cyan,gray — the
      # "brown" slot is the conventional yellow, matching kitty/tmux mappings.
      graphicalTerminal = {
        foreground = c "fg";
        brightForeground = c "fgBrighter";
        palette = colors [
          "bg0"
          "red"
          "green"
          "yellow"
          "blue"
          "purple"
          "aqua"
          "grayBright"
        ];
        brightPalette = colors [
          "gray"
          "red"
          "green"
          "yellow"
          "blue"
          "purple"
          "aqua"
          "fg"
        ];
      };
    };
  };
}
