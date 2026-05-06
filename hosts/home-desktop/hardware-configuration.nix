# hosts/home-desktop/hardware-configuration.nix — Placeholder for home-desktop.
# Replace with the output of: sudo nixos-generate-config --root /mnt
# Then copy the generated /mnt/etc/nixos/hardware-configuration.nix here.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # ── TODO: replace with generated hardware-configuration.nix ─────────────────
  # Run on the target machine:
  #   sudo nixos-generate-config --root /mnt
  # Then copy /mnt/etc/nixos/hardware-configuration.nix into this file.
  # NOTE: Do NOT define fileSystems here — disko manages them via disk-config.nix.

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
