# hosts/work-laptop/default.nix — Work laptop (Hyprland, TLP, no gaming/nvidia).
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
  ];

  # ── Base ─────────────────────────────────────────────────────────────────────
  custom.base = {
    enable = true;
    username = "max";
    timezone = "Europe/London";
    powerManagement = "tlp";
    firewall = true;
    plymouth.enable = true;
  };

  # ── Development ──────────────────────────────────────────────────────────────
  custom.development = {
    enable = true;
    containers.podman.enable = true;
    containers.libvirt.enable = false;
    database.guiClients.enable = true;
    database.dataPlatforms.enable = false;
    cloudTools.enable = true;
  };

  # ── Productivity (Hyprland) ───────────────────────────────────────────────────
  custom.productivity = {
    enable = true;
    communicationApps.enable = true;
  };

  # ── TLP battery management ────────────────────────────────────────────────────
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      WIFI_PWR_ON_BAT = 5;
      NMI_WATCHDOG = 0;
    };
  };

  # ── Bootloader ────────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Networking ───────────────────────────────────────────────────────────────
  networking.hostName = "work-laptop";

  system.stateVersion = "24.11";
}
