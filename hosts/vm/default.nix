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
    ../common/optional/plymouth.nix
    ../common/optional/limine.nix
  ];

  home-manager.backupFileExtension = "backup";

  custom.base = {
    enable = true;
    username = "max";
    timezone = "Pacific/Auckland";
    hashedPassword = "$y$j9T$2U13TXbQqrmp.PD068E0E.$1uJPVe1dF1C0KhlXbn.iMg2qthRxOdp.9s/h6GG6YC6";
    sshKeys = [ ];
  };

  # Limine bootloader comes from ../common/optional/limine.nix.
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "vm";

  # SilentSDDM sets InputMethod = "qtvirtualkeyboard" which steals pointer events
  # in QEMU VMs. Clearing it restores normal mouse input on the login screen.
  services.displayManager.sddm.settings.General.InputMethod = lib.mkForce "";

  # SilentSDDM sets wayland.enable = !xserver.enable. Enabling xserver switches
  # SDDM to X11 mode, which uses software cursors — required because QEMU's GPU
  # doesn't support hardware cursor planes (cursor renders invisible in Wayland).
  # Hyprland still launches as a Wayland session via UWSM regardless.
  services.xserver.enable = true;

  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 8192;
      cores = 8;
      diskSize = 20480;
    };
  };

  system.stateVersion = "24.11";
}
