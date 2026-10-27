# btrfs.nix — for hosts whose disko layout is btrfs with /nix on its own
# subvolume (all four).
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

  # Monthly scrub: reads every block back and checks it against its checksum,
  # so silent corruption shows up in `btrfs scrub status /` rather than when a
  # file is next opened. Every btrfs mount is listed by default, deduplicated
  # by device, so the subvolumes of one disk are scrubbed once.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };
}
