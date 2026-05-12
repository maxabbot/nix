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
    secondaryBrowsers.enable = true; # google-chrome — wired into mime defaults
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

  # ── SDDM: show greeter on DP-3 (1440p primary), not DP-2 (4K portrait) ───────
  # pkgs.writeText puts the JSON in the Nix store; the activation script copies
  # it into the sddm user's config dir — no heredoc, no indentation issues.
  system.activationScripts.sddmMonitorConfig =
    let
      kwinCfg = pkgs.writeText "kwinoutputconfig.json" (builtins.toJSON {
        outputs = [
          {
            connector = "DP-3";
            enabled = true;
            mode = {
              width = 2560;
              height = 1440;
              refreshRate = 165000;
            };
            pos = {
              x = 0;
              y = 0;
            };
            scale = 1.0;
            transform = 0;
          }
          {
            connector = "DP-2";
            enabled = false;
          }
        ];
      });
    in
    {
      deps = [ "users" ];
      text = ''
        mkdir -p /var/lib/sddm/.config
        cp ${kwinCfg} /var/lib/sddm/.config/kwinoutputconfig.json || true
        chown sddm:sddm /var/lib/sddm/.config/kwinoutputconfig.json 2>/dev/null || true
        chmod 600 /var/lib/sddm/.config/kwinoutputconfig.json 2>/dev/null || true
      '';
    };

  # ── Bootloader ────────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Networking ───────────────────────────────────────────────────────────────
  networking.hostName = "home-desktop";

  system.stateVersion = "24.11";
}
