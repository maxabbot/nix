# hosts/home-desktop/hardware-configuration.nix — Placeholder for home-desktop.
# Replace with the output of: sudo nixos-generate-config --root /mnt
# Then copy the generated /mnt/etc/nixos/hardware-configuration.nix here.
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # ── TODO: replace with generated hardware-configuration.nix ─────────────────
  # Run on the target machine:
  #   sudo nixos-generate-config --root /mnt
  # Then copy /mnt/etc/nixos/hardware-configuration.nix into this file.

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules          = [];
  boot.kernelModules                 = [ "kvm-intel" ];
  boot.extraModulePackages           = [];

  # ── Example BTRFS layout — update device paths before use ────────────────────
  fileSystems."/" = {
    device  = "/dev/disk/by-label/nixos";
    fsType  = "btrfs";
    options = [ "subvol=@" "compress=zstd" "noatime" ];
  };

  fileSystems."/home" = {
    device  = "/dev/disk/by-label/nixos";
    fsType  = "btrfs";
    options = [ "subvol=@home" "compress=zstd" "noatime" ];
  };

  fileSystems."/nix" = {
    device  = "/dev/disk/by-label/nixos";
    fsType  = "btrfs";
    options = [ "subvol=@nix" "compress=zstd" "noatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
