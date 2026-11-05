# hosts/vm/default.nix — Home-desktop stack in a QEMU/virtio VM (no NVIDIA, no fancontrol).
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../modules/nixos/base.nix
    ../common/optional/development.nix
    ../common/optional/podman.nix
    ../common/optional/libvirt.nix
    ../common/optional/db-gui.nix
    ../common/optional/duckdb.nix
    ../common/optional/cloud-tools.nix
    ../common/optional/productivity.nix
    ../common/optional/creative-apps.nix
    ../common/optional/streaming-tools.nix
    ../common/optional/google-chrome.nix
    ../common/optional/comms.nix
    ../common/optional/onedrive.nix
    ../common/optional/pwas.nix
    ../common/optional/stylix.nix
    ../common/optional/gaming.nix
    ../common/optional/wine.nix
    ../common/optional/plymouth.nix
    ../common/optional/btrfs.nix
    ../common/optional/sops.nix
    ../common/optional/limine.nix
  ];

  custom.base.enable = true;

  # Limine bootloader comes from ../common/optional/limine.nix.
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "vm";

  # QEMU's GPU has no hardware cursor planes, so a hardware cursor renders
  # invisible: draw the greeter's in software (the session's comes from
  # hyprland.lua's softwareCursor).
  services.displayManager.dms-greeter.compositor.customConfig = ''
    hl.config({ cursor = { no_hardware_cursors = 1 } })
  '';

  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 8192;
      cores = 8;
      diskSize = 20480;
    };
  };

  system.stateVersion = "24.11";
}
