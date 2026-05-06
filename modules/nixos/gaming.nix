# modules/nixos/gaming.nix — Steam, Wine, Proton, controllers, and performance tools.
# Mirrors system/roles/gaming from the Arch Ansible layer.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.gaming;
in
{
  options.custom.gaming = {
    enable = lib.mkEnableOption "gaming stack";

    wineExtras.enable = lib.mkEnableOption "DXVK / VKD3D-Proton Wine translation layers";
    streaming.enable = lib.mkEnableOption "game streaming / overlay tools (OBS, Moonlight, GOverlay)";
    apollo.enable = lib.mkEnableOption "Apollo game streaming server";
    extraGpuVendors.enable = lib.mkEnableOption "extra Vulkan ICDs for non-NVIDIA GPUs (Intel, AMD)";
  };

  config = lib.mkIf cfg.enable {
    # ── Steam ──────────────────────────────────────────────────────────────────
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = false;
      gamescopeSession.enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };

    # ── Gamemode ───────────────────────────────────────────────────────────────
    programs.gamemode = {
      enable = true;
      enableRenice = true;
      settings.general = {
        renice = 10;
        inhibit_screensaver = 1;
      };
    };

    # ── MangoHUD + Gamescope ───────────────────────────────────────────────────
    programs.gamescope.enable = true;
    environment.systemPackages = [ pkgs.mangohud ];

    # ── System packages ────────────────────────────────────────────────────────
    environment.systemPackages =
      with pkgs;
      [
        # Wine (base + compat layers)
        wineWowPackages.staging
        wine-mono
        winetricks

        # Controller support
        joyutils

        # Gaming utilities
        protonup-qt
        protontricks
        heroic
        itch
        goverlay
        vkbasalt

        # Vulkan / GPU tools
        vulkan-tools
        vulkan-validation-layers
        vulkan-loader
        glmark2
      ]
      ++ lib.optionals cfg.streaming.enable [
        obs-studio
        moonlight-qt
      ]
      ++ lib.optionals cfg.wineExtras.enable [
        dxvk
      ]
      ++ lib.optionals cfg.extraGpuVendors.enable [
        mesa
        intel-media-driver
      ]
      ++ lib.optionals cfg.apollo.enable [
        # apollo-bin — add custom derivation to overlays/default.nix when ready
      ];

    # ── xpadneo — Xbox controller kernel module ────────────────────────────────
    boot.extraModulePackages = [ config.boot.kernelPackages.xpadneo ];

    # ── 32-bit support for Steam / Wine ───────────────────────────────────────
    hardware.graphics.enable32Bit = true;

    # ── udev rules for controllers ─────────────────────────────────────────────
    services.udev.packages = [ pkgs.steam ];

    # ── Kernel parameters for low-latency gaming ──────────────────────────────
    boot.kernel.sysctl = {
      "vm.max_map_count" = 2147483642; # required by some games / anti-cheat
    };
  };
}
