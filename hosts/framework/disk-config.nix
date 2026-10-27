# hosts/framework/disk-config.nix — Declarative disk layout via disko (LUKS + btrfs).
#
# Used by nixos-anywhere for automated installation:
#   nix run github:nix-community/nixos-anywhere -- --flake .#framework nixos@<ip>
#
# Verify the disk name with `lsblk` on the live ISO before running — the
# Framework 13's single M.2 slot normally enumerates as /dev/nvme0n1.
#
# Layout: 1G unencrypted ESP (Limine + kernel + initrd live here) followed by a
# LUKS2 container holding the btrfs root. `askPassword` makes the installer
# prompt for the passphrase interactively; initrd (systemd-based, see
# default.nix) prompts again at every boot to unlock it.
#
# Swap is a swapfile on its own @swap subvolume, there for hibernation (see
# the lid block in default.nix). It has to be in the layout from the start:
# disko only creates subvolumes at install time.
_: {
  disko.devices = {
    # The disk name determines the GPT partlabels (disk-nvme-*) that the boot
    # mounts resolve through — keep it unique across machines so this drive
    # never collides with another disko-installed disk (disk-main-* on
    # home-desktop, disk-usbssd-* on the portable work-laptop SSD).
    disk.nvme = {
      type = "disk";
      device = "/dev/nvme0n1";
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
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot"; # → /dev/mapper/cryptroot
              # Prompt for the passphrase during `nixos-anywhere` / `disko`.
              askPassword = true;
              settings = {
                # Pass TRIM through to the NVMe. Slight confidentiality
                # trade-off (free-space patterns become visible) in exchange
                # for the SSD not degrading over time — the usual laptop call.
                allowDiscards = true;
              };
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
                  # Its own subvolume because btrfs refuses to snapshot one that
                  # holds an active swapfile, which would rule out snapshots of
                  # @. disko creates it with `btrfs filesystem mkswapfile`
                  # (nodatacow, so compress= wouldn't apply) and adds the
                  # swapDevices entry. Sized to hold a hibernation image of the
                  # whole RAM: raise it if the machine has more than 32 GiB.
                  # zram (base.nix) keeps the higher priority, so this only
                  # takes overflow and hibernation.
                  "@swap" = {
                    mountpoint = "/.swapvol";
                    swap.swapfile.size = "32G";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
