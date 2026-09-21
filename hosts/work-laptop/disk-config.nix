# hosts/work-laptop/disk-config.nix — Declarative disk layout via disko.
#
# Used by nixos-anywhere for automated installation:
#   nix run github:nix-community/nixos-anywhere -- --flake .#work-laptop nixos@<ip>
#
# Verify your disk name with `lsblk` on the live ISO before running.
# Default assumes /dev/sda — change `device` if different (e.g. /dev/nvme0n1).
#
# No swap partition: swap is a 16G swapfile on the root subvolume, declared in
# hardware-configuration.nix. Kept out of the partition table deliberately so it
# can be resized on a live system instead of only at disko install time.
_: {
  disko.devices = {
    # The disk name determines the GPT partlabels (disk-usbssd-*) that boot
    # mounts resolve through — keep it unique across machines so this USB drive
    # never collides with another disko-installed disk in the same system.
    disk.usbssd = {
      type = "disk";
      device = "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [
                "fmask=0077"
                "dmask=0077"
              ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "@" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@log" = {
                  mountpoint = "/var/log";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
              };
            };
          };
        };
      };
    };
  };
}
