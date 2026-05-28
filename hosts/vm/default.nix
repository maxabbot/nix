# hosts/vm/default.nix — Home-desktop stack in a QEMU/virtio VM (no NVIDIA, no fancontrol).
{ lib, ... }:
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

  # SilentSDDM sets InputMethod = "qtvirtualkeyboard" which steals pointer events
  # in QEMU VMs. Clearing it restores normal mouse input on the login screen.
  services.displayManager.sddm.settings.General.InputMethod = "";

  # SDDM Wayland mode (weston) uses hardware cursor planes that QEMU's GPU doesn't
  # support — cursor is functional but invisible. X11 mode uses software cursors.
  # Hyprland still launches as a Wayland session via UWSM regardless.
  services.displayManager.sddm.wayland.enable = lib.mkForce false;

  system.stateVersion = "24.11";
}
