# plymouth.nix — Boot splash between the Limine menu and SDDM, on every host.
# Gruvbox bg0 with a spinning NixOS snowflake, matching Limine and the greeter.
# On framework the systemd initrd hands the LUKS passphrase prompt to it, so
# the unlock screen is themed too.
#
# The theme is ours rather than Stylix's plymouth target (disabled in
# stylix.nix): config/plymouth/gruvbox.script is that target's script with the
# layout recomputed every frame, so the logo stays centred when the displays
# change mid-splash — see the script header. Both it and the logo
# (config/plymouth/nix-snowflake.svg, one palette accent per lambda) are
# palette-subst.nix templates.
#
# The splash needs a KMS driver in the initrd or it only appears late (or not
# at all): nvidia.nix adds the NVIDIA modules, nixos-hardware loads xe on
# framework, and work-laptop's hardware config has i915.
#
# systemd stage 1 on every host: Plymouth runs as a unit from the start and
# carries through to stage 2 without a restart, and units that only exist in
# the systemd initrd (home-desktop's initrd-find-nixos-closure retry for
# btrfs's first mount) actually apply. Its emergency shell is locked by
# default — set boot.initrd.systemd.emergencyAccess to get one. The scripted
# hooks (postDeviceCommands etc.) don't run under it; nothing here uses them.
{ lib, pkgs, ... }:
let
  renderTheme = import ../../../config/stylix/palette-subst.nix { inherit lib; };
  script = pkgs.writeText "gruvbox.script" (renderTheme ../../../config/plymouth/gruvbox.script);
  logo = pkgs.writeText "nix-snowflake-gruvbox.svg" (
    renderTheme ../../../config/plymouth/nix-snowflake.svg
  );

  theme =
    pkgs.runCommand "plymouth-theme-gruvbox"
      {
        nativeBuildInputs = [
          pkgs.librsvg
          pkgs.imagemagick
        ];
      }
      ''
        themeDir="$out/share/plymouth/themes/gruvbox"
        mkdir -p "$themeDir"

        # 256 px snowflake; the transparent border keeps the corners from being
        # clipped when the script rotates it.
        rsvg-convert -w 256 -h 256 ${logo} -o logo.png
        magick logo.png -background transparent -bordercolor transparent \
          -border 42% "$themeDir/logo.png"

        cp ${script} "$themeDir/gruvbox.script"

        cat > "$themeDir/gruvbox.plymouth" <<EOF
        [Plymouth Theme]
        Name=Gruvbox
        ModuleName=script

        [script]
        ImageDir=$themeDir
        ScriptFile=$themeDir/gruvbox.script
        EOF
      '';
in
{
  boot = {
    plymouth = {
      enable = true;
      theme = "gruvbox";
      themePackages = [ theme ];
    };
    consoleLogLevel = 0;
    initrd = {
      systemd.enable = true;
      verbose = false;
    };
    kernelParams = [
      "quiet"
      "splash"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
  };
}
