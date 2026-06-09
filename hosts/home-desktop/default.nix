# hosts/home-desktop/default.nix — Gaming/desktop workstation (RTX 40-series, Hyprland).
{ config, pkgs, ... }:
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
    ../common/optional/nvidia.nix
    ../common/optional/cuda.nix
    ../common/optional/gaming.nix
    ../common/optional/wine.nix
    ../common/optional/gaming-streaming.nix
  ];

  home-manager.backupFileExtension = "backup";

  # ── Base ─────────────────────────────────────────────────────────────────────
  custom.base = {
    enable = true;
    username = "max";
    timezone = "Pacific/Auckland";
    hashedPassword = "$y$j9T$2U13TXbQqrmp.PD068E0E.$1uJPVe1dF1C0KhlXbn.iMg2qthRxOdp.9s/h6GG6YC6";
    sshKeys = [ ]; # add your public key: "ssh-ed25519 AAAA..."
    powerManagement = "power-profiles-daemon";
    firewall = true;
    fancontrol = {
      enable = true;
      config = ''
        INTERVAL=10
        DEVPATH=hwmon2=/sys/devices/platform/it87.2624/hwmon/hwmon2
        DEVNAME=hwmon2=it8628
        FCTEMPS=hwmon2/pwm1=hwmon4/temp1_input hwmon2/pwm3=hwmon4/temp1_input hwmon2/pwm4=hwmon4/temp1_input
        FCFANS=hwmon2/pwm1=hwmon2/fan1_input hwmon2/pwm3=hwmon2/fan3_input hwmon2/pwm4=hwmon2/fan4_input
        MINTEMP=hwmon2/pwm1=40 hwmon2/pwm3=40 hwmon2/pwm4=40
        MAXTEMP=hwmon2/pwm1=75 hwmon2/pwm3=75 hwmon2/pwm4=75
        MINSTART=hwmon2/pwm1=50 hwmon2/pwm3=50 hwmon2/pwm4=50
        MINSTOP=hwmon2/pwm1=30 hwmon2/pwm3=30 hwmon2/pwm4=30
      '';
    };
  };

  # SDDM greeter compositor — KWin, overriding productivity.nix's weston default
  # (that default is for the QEMU VM, which has no hardware cursor). KWin is
  # required for the kwinoutputconfig.json below to be honoured; weston ignores
  # it, which leaves the greeter on the rotated 4K monitor.
  services.displayManager.sddm.wayland.compositor = "kwin";

  # ── SDDM: show greeter on DP-3 only ─────────────────────────────────────────
  # Activation runs on every boot before SDDM starts. chmod 444 prevents KWin
  # (running as sddm) from overwriting the config during the greeter session.
  # UUIDs/EDID values are stable hardware identifiers for this machine.
  system.activationScripts.sddmMonitorConfig =
    let
      kwinCfg = pkgs.writeText "kwinoutputconfig.json" (
        builtins.toJSON [
          {
            name = "outputs";
            data = [
              {
                # DP-2 — AOC 4K (3840x2160 @ 60 Hz), index 0
                allowDdcCi = true;
                allowSdrSoftwareBrightness = true;
                autoBrightnessCurve = [
                  0
                  0
                  0
                  0
                  0
                  0
                ];
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
                mode = {
                  height = 2160;
                  refreshRate = 60000;
                  width = 3840;
                };
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
                # DP-3 — AOC 1440p (2560x1440 @ 165 Hz), index 1 (primary — enabled in SDDM)
                allowDdcCi = true;
                allowSdrSoftwareBrightness = true;
                autoBrightnessCurve = [
                  0
                  0
                  0
                  0
                  0
                  0
                ];
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
                mode = {
                  height = 1440;
                  refreshRate = 165000;
                  width = 2560;
                };
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
              {
                # HDMI-A-1 — Philips FTV 4K TV (3840x2160 @ 30 Hz), index 2
                allowDdcCi = true;
                allowSdrSoftwareBrightness = true;
                autoBrightnessCurve = [
                  0
                  0
                  0
                  0
                  0
                  0
                ];
                autoRotation = "InTabletMode";
                automaticBrightness = false;
                brightness = 1;
                colorPowerTradeoff = "PreferEfficiency";
                colorProfileSource = "sRGB";
                connectorName = "HDMI-A-1";
                detectedDdcCi = false;
                edidHash = "273be949ec959ea226fcebc0e1240bb0";
                edidIdentifier = "PHL 2947 16843009 10 2022 0";
                edrPolicy = "always";
                highDynamicRange = false;
                iccProfilePath = "";
                maxBitsPerColor = 0;
                mode = {
                  height = 2160;
                  refreshRate = 60000;
                  width = 3840;
                };
                overscan = 0;
                rgbRange = "Automatic";
                scale = 2;
                sdrBrightness = 200;
                sdrGamutWideness = 0;
                sharpness = 0;
                transform = "Normal";
                uuid = "";
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
                    enabled = false; # TV — off during SDDM
                    outputIndex = 2;
                    position = {
                      x = 0;
                      y = 0;
                    };
                    priority = 0;
                    replicationSource = "";
                  }
                  {
                    enabled = false; # DP-2 — off during SDDM
                    outputIndex = 0;
                    position = {
                      x = 2560;
                      y = 0;
                    };
                    priority = 0;
                    replicationSource = "";
                  }
                  {
                    enabled = true; # DP-3 primary
                    outputIndex = 1;
                    position = {
                      x = 0;
                      y = 0;
                    };
                    priority = 1;
                    replicationSource = "";
                  }
                ];
              }
            ];
          }
        ]
      );
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

  # ── Audio — route NVIDIA HDMI audio to the TV (HDMI 3 = Philips FTV) ────────
  # Without this, WirePlumber defaults to hdmi-stereo (HDMI 0 = U27B35 monitor).
  services.pipewire.wireplumber.extraConfig."10-nvidia-tv-audio" = {
    "monitor.alsa.rules" = [
      {
        matches = [ { "device.name" = "alsa_card.pci-0000_01_00.1"; } ];
        actions.update-props."device.profile" = "output:hdmi-stereo-extra2";
      }
    ];
  };
  services.pipewire.wireplumber.extraConfig."20-default-tv-sink" = {
    "wireplumber.settings"."default.configured-audio-sink" = "alsa_output.pci-0000_01_00.1.hdmi-stereo-extra2";
  };

  boot = {
    # ── ITE IT8689E hardware monitor (Gigabyte Z790 UD AX) ─────────────────────
    # Mainline it87 doesn't support this chip; the out-of-tree driver does.
    # Required for pwmconfig / fancontrol to see PWM controls.
    extraModulePackages = [ config.boot.kernelPackages.it87 ];
    kernelModules = [ "it87" ];

    # ── Bootloader ──────────────────────────────────────────────────────────────
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    # btrfs "first mount" free-space-tree init creates a brief window where the
    # @nix subvolume is mounted but path lookups fail; retry instead of panicking.
    initrd.systemd.services.initrd-find-nixos-closure.serviceConfig = {
      Restart = "on-failure";
      RestartSec = "3";
      StartLimitBurst = 10;
      StartLimitIntervalSec = "60";
    };
  };

  # ── udev ─────────────────────────────────────────────────────────────────────
  # NuPhy Air75 V3 — grants userspace hidraw access for nuphy.io configurator
  services.udev.extraRules = ''
    KERNEL=="hidraw*", ATTRS{idVendor}=="19f5", ATTRS{idProduct}=="1028", MODE="0666"
  '';

  # ── Networking ───────────────────────────────────────────────────────────────
  networking.hostName = "home-desktop";

  system.stateVersion = "24.11";
}
