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
    initialPassword = "123"; # change after first login
    sshKeys = [ ]; # add your public key: "ssh-ed25519 AAAA..."
    powerManagement = "power-profiles-daemon";
    firewall = true;
    plymouth.enable = true;
  };

  # ── Development ──────────────────────────────────────────────────────────────
  custom.development = {
    enable = true;
    containers.podman.enable = true;
    containers.libvirt.enable = true;
    database.guiClients.enable = true;
    database.dataPlatforms.enable = true;
    cloudTools.enable = true;
  };

  # ── Productivity (Hyprland desktop) ──────────────────────────────────────────
  custom.productivity = {
    enable = true;
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

  system.stateVersion = "24.11";
}
