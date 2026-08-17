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
# No swap partition — base.nix enables zram instead, which is why hibernation
# is not available on this host. Add a swapfile inside @swap if that changes.
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
                };
              };
            };
          };
        };
      };
    };
  };
}
