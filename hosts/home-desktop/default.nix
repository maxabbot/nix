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
    fancontrol = {
      enable = true;
      # config = builtins.readFile ./fancontrol; # run: sudo pwmconfig > hosts/home-desktop/fancontrol
    };
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

  # ── SDDM: show greeter on DP-3 only ─────────────────────────────────────────
  # Activation runs on every boot before SDDM starts. chmod 444 prevents KWin
  # (running as sddm) from overwriting the config during the greeter session.
  # UUIDs/EDID values are stable hardware identifiers for this machine.
  system.activationScripts.sddmMonitorConfig =
    let
      kwinCfg = pkgs.writeText "kwinoutputconfig.json" (builtins.toJSON [
        {
          name = "outputs";
          data = [
            {
              # DP-2 — AOC 4K (3840x2160 @ 60 Hz), index 0
              allowDdcCi = true;
              allowSdrSoftwareBrightness = true;
              autoBrightnessCurve = [ 0 0 0 0 0 0 ];
              autoRotation = "InTabletMode";
              automaticBrightness = false;
              brightness = 1;
              colorPowerTradeoff = "PreferEfficiency";
              colorProfileSource = "sRGB";
              connectorName = "DP-2";
              detectedDdcCi = false;
              edidHash = "20a8bbcf2ded99e2c8954fef4ad4d197";
              edidIdentifier = "AOC 9987 121 9 2026 0";
              edrPolicy = "always";
              highDynamicRange = false;
              iccProfilePath = "";
              maxBitsPerColor = 0;
              mode = { height = 2160; refreshRate = 60000; width = 3840; };
              overscan = 0;
              rgbRange = "Automatic";
              scale = 1.7;
              sdrBrightness = 417;
              sdrGamutWideness = 0;
              sharpness = 0;
              transform = "Normal";
              uuid = "1c32b0ef-a8c6-4efd-805a-8ab0baaaa435";
              vrrPolicy = "Never";
              wideColorGamut = false;
            }
            {
              # DP-3 — AOC 1440p (2560x1440 @ 165 Hz), index 1
              allowDdcCi = true;
              allowSdrSoftwareBrightness = true;
              autoBrightnessCurve = [ 0 0 0 0 0 0 ];
              autoRotation = "InTabletMode";
              automaticBrightness = false;
              brightness = 1;
              colorPowerTradeoff = "PreferEfficiency";
              colorProfileSource = "sRGB";
              connectorName = "DP-3";
              detectedDdcCi = false;
              edidHash = "4eb9ea281bef29a9e73ebce35b13ec11";
              edidIdentifier = "AOC 45829 3301 22 2023 0";
              edrPolicy = "always";
              highDynamicRange = false;
              iccProfilePath = "";
              maxBitsPerColor = 0;
              mode = { height = 1440; refreshRate = 165000; width = 2560; };
              overscan = 0;
              rgbRange = "Automatic";
              scale = 1;
              sdrBrightness = 301;
              sdrGamutWideness = 0;
              sharpness = 0;
              transform = "Normal";
              uuid = "9537cafe-ef6f-4f25-8c94-eb1ff9bf734b";
              vrrPolicy = "Never";
              wideColorGamut = false;
            }
          ];
        }
        {
          name = "setups";
          data = [
            {
              lidClosed = false;
              outputs = [
                {
                  enabled = false; # DP-2 disabled at login
                  outputIndex = 0;
                  position = { x = 0; y = 0; };
                  priority = 0;
                  replicationSource = "";
                }
                {
                  enabled = true; # DP-3 primary
                  outputIndex = 1;
                  position = { x = 0; y = 0; };
                  priority = 1;
                  replicationSource = "";
                }
              ];
            }
          ];
        }
      ]);
    in
    {
      deps = [ "users" ];
      text = ''
        mkdir -p /var/lib/sddm/.config
        cp ${kwinCfg} /var/lib/sddm/.config/kwinoutputconfig.json
        chown sddm:sddm /var/lib/sddm/.config/kwinoutputconfig.json
        chmod 444 /var/lib/sddm/.config/kwinoutputconfig.json
      '';
    };

  # ── ITE IT8689E hardware monitor (Gigabyte Z790 UD AX) ───────────────────────
  # Mainline it87 doesn't support this chip; the out-of-tree driver does.
  # Required for pwmconfig / fancontrol to see PWM controls.
  boot.extraModulePackages = [ config.boot.kernelPackages.it87 ];
  boot.kernelModules = [ "it87" ];

  # ── Bootloader ────────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Networking ───────────────────────────────────────────────────────────────
  networking.hostName = "home-desktop";

  system.stateVersion = "24.11";
}
