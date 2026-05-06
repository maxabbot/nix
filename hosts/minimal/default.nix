# hosts/minimal/default.nix — Minimal headless / server profile.
# Equivalent to the minimal Ansible profile (base only).
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
    ../../modules/nixos/base.nix
  ];

  custom.base = {
    enable = true;
    username = "max";
    timezone = "UTC";
    btrfsSnapshots = false;
    firewall = true;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "minimal";

  # ── Home Manager (shell only — no GUI) ────────────────────────────────────────
  home-manager.users.max = import ../../home/max/default.nix;
  home-manager.extraSpecialArgs = {
    machineType = "server";
    compositor = "none";
    monitors = {
      primary = null;
      secondary = null;
    };
    git = {
      name = "Max Abbot";
      email = "abbot.max.nz@gmail.com";
    };
    location = {
      latitude = 0.0;
      longitude = 0.0;
    };
    inherit inputs;
  };

  system.stateVersion = "24.11";
}
