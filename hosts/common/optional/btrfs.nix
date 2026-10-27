# btrfs.nix — for hosts whose disko layout puts /nix on its own btrfs subvolume
# (home-desktop, framework).
#
# The retry is a systemd-initrd unit, so it relies on the systemd stage 1 that
# plymouth.nix turns on for every host.
_: {
  # btrfs "first mount" free-space-tree init creates a brief window where the
  # @nix subvolume is mounted but path lookups fail; retry instead of panicking.
  boot.initrd.systemd.services.initrd-find-nixos-closure.serviceConfig = {
    Restart = "on-failure";
    RestartSec = "3";
    StartLimitBurst = 10;
    StartLimitIntervalSec = "60";
  };
}
