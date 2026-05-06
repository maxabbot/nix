# hosts/home-desktop/default.nix — Gaming/desktop workstation (RTX 40-series, Hyprland).
# Equivalent to the home_desktop Ansible profile.
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/development.nix
    ../../modules/nixos/productivity.nix
    ../../modules/nixos/nvidia.nix
    ../../modules/nixos/gaming.nix
  ];

  # ── Base ─────────────────────────────────────────────────────────────────────
  custom.base = {
    enable = true;
    username = "max";
    timezone = "Pacific/Auckland";
    btrfsSnapshots = true;
    powerManagement = "power-profiles-daemon";
    firewall = true;
  };

  # ── Development ──────────────────────────────────────────────────────────────
  custom.development = {
    enable = true;
    containers.podman.enable = true;
    containers.libvirt.enable = true;
    database.servers.enable = true;
    database.guiClients.enable = true;
    database.dataPlatforms.enable = true;
    cloudTools.enable = true;
  };

  # ── Productivity (Hyprland desktop) ──────────────────────────────────────────
  custom.productivity = {
    enable = true;
    compositor = "hyprland";
    creativeApps.enable = true;
    streamingTools.enable = true;
    communicationApps.enable = true;
  };

  # ── NVIDIA RTX 40-series ──────────────────────────────────────────────────────
  custom.nvidia = {
    enable = true;
    open = true;
    cuda.enable = true;
  };

  # ── Gaming ────────────────────────────────────────────────────────────────────
  custom.gaming = {
    enable = true;
    wineExtras.enable = true;
    streaming.enable = true;
  };

  # ── Bootloader ────────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Networking ───────────────────────────────────────────────────────────────
  networking.hostName = "home-desktop";

  # ── Home Manager ─────────────────────────────────────────────────────────────
  home-manager.users.max = import ../../home/max/default.nix;
  home-manager.extraSpecialArgs = {
    machineType = "desktop";
    compositor = "hyprland";
    monitors = {
      primary = "DP-1,2560x1440@144,0x0,1";
      secondary = null;
    };
    git = {
      name = "Max Abbot";
      email = "abbot.max.nz@gmail.com";
    };
    location = {
      latitude = -43.53; # Christchurch, NZ
      longitude = 172.64;
    };
    inherit inputs;
  };

  system.stateVersion = "24.11";
}
