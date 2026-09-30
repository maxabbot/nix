# plymouth.nix — Boot splash between the Limine menu and SDDM, on every host.
# The theme comes from Stylix's plymouth target (hosts/common/optional/
# stylix.nix): Gruvbox bg0 with a spinning NixOS snowflake, matching Limine
# and the greeter. On framework the systemd initrd hands the LUKS passphrase
# prompt to it, so the unlock screen is themed too.
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
_: {
  boot = {
    plymouth.enable = true;
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
