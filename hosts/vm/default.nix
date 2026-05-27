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
    ../common/optional/stylix.nix
    ../common/optional/gaming.nix
    ../common/optional/wine.nix
  ];

  home-manager.backupFileExtension = "backup";

  custom.base = {
    enable = true;
    username = "max";
    timezone = "Pacific/Auckland";
    initialPassword = "123";
    sshKeys = [ ];
    powerManagement = "power-profiles-daemon";
    firewall = true;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "vm";

  system.stateVersion = "24.11";
}
