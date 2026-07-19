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
    ../common/optional/fan2go.nix
    ../common/optional/lan-mouse.nix
    ../common/optional/limine.nix
  ];

  home-manager.backupFileExtension = "backup";

  # ── Base ─────────────────────────────────────────────────────────────────────
  custom.base = {
    enable = true;
    username = "max";
    hashedPassword = "$y$j9T$2U13TXbQqrmp.PD068E0E.$1uJPVe1dF1C0KhlXbn.iMg2qthRxOdp.9s/h6GG6YC6";
    sshKeys = [ ]; # add your public key: "ssh-ed25519 AAAA..."
    # Fan control moved to fan2go (../common/optional/fan2go.nix) for moving-average
    # temperature smoothing — fancontrol only point-sampled and hunted on CPU spikes.
    fancontrol.enable = false;
  };

  # ── Nix builds ───────────────────────────────────────────────────────────────
  # base.nix caps max-jobs at 1 for the RAM-constrained, swap-less hosts. This box
  # has 62 GiB, so restore full build parallelism (one job per core).
  nix.settings.max-jobs = "auto";

  # ── Steam gamescope session (SDDM "Steam" entry) ─────────────────────────────
  # gaming.nix enables gamescopeSession but leaves args empty, so gamescope
  # defaults to 720p @ 60 Hz and may render to the wrong connector — hence the
  # off resolution and lag on this 1440p/165 Hz panel. Pin the DP-3 gaming mode
  # (this is host-specific, which is why it lives here and not in shared
  # gaming.nix, whose vm host has no DP-3). Mirrors gaming-toggle.sh's -W/-H/-r.
  # --rt requests realtime scheduling for lower input latency.
  programs.steam.gamescopeSession.args = [
    "-W"
    "2560"
    "-H"
    "1440"
    "-r"
    "165"
    "-O"
    "DP-3"
    "--rt"
  ];

  services = {
    # SDDM greeter compositor — KWin, overriding productivity.nix's weston default
    # (that default is for the QEMU VM, which has no hardware cursor). KWin is
    # required for the kwinoutputconfig.json below to be honoured; weston ignores
    # it, which leaves the greeter on the rotated 4K monitor.
    displayManager.sddm.wayland.compositor = "kwin";

    # ── Audio ──────────────────────────────────────────────────────────────────
    # Route NVIDIA HDMI audio to the TV (HDMI 3 = Philips FTV); without this,
    # WirePlumber picks hdmi-stereo (HDMI 0 = U27B35 monitor).
    # Default sink is the Built-in analog line out for general apps (waybar etc).
    pipewire.wireplumber.extraConfig = {
      "10-nvidia-tv-audio" = {
        "monitor.alsa.rules" = [
          {
            matches = [ { "device.name" = "alsa_card.pci-0000_01_00.1"; } ];
            actions.update-props."device.profile" = "output:hdmi-stereo-extra2";
          }
        ];
      };
      # Make the onboard analog line-out the default sink. WirePlumber picks the
      # highest-priority node as the auto-default, so raise analog above the
      # NVIDIA HDMI outputs. NOTE: a *manually* chosen default (pavucontrol or the
      # Super+O switcher) is stored in ~/.local/state/wireplumber/default-nodes
      # and overrides priority — if HDMI ever sticks, clear it with
      # `wpctl set-default <analog-id>`.
      "20-default-sink" = {
        "node.rules" = [
          {
            matches = [ { "node.name" = "alsa_output.pci-0000_00_1f.3.analog-stereo"; } ];
            actions.update-props = {
              "priority.session" = 2000;
              "priority.driver" = 2000;
            };
          }
        ];
      };
    };

    # ── udev ───────────────────────────────────────────────────────────────────
    # NuPhy Air75 V3 — grants userspace hidraw access for nuphy.io configurator.
    # 0660 + input group instead of world-writable 0666; the primary user is in
    # "input" (base.nix). TAG+="uaccess" won't work here: extraRules lands in
    # 99-local.rules, after 73-seat-late.rules has already processed the tag.
    #
    # Logitech Bolt receiver (mouse) — strip its USB wakeup so a nudged mouse
    # can't resume the machine from suspend; waking is keyboard/power-button only.
    udev.extraRules = ''
      KERNEL=="hidraw*", ATTRS{idVendor}=="19f5", ATTRS{idProduct}=="1028", MODE="0660", GROUP="input"
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="c548", ATTR{power/wakeup}="disabled"
    '';
  };

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

  # ── DDC/CI ───────────────────────────────────────────────────────────────────
  # Loads i2c-dev and grants i2c-bus access (the "i2c" group / seat users) so the
  # Quickshell Display tab can drive external-monitor brightness via ddcutil.
  hardware.i2c.enable = true;

  boot = {
    # ── ITE IT8689E hardware monitor (Gigabyte Z790 UD AX) ─────────────────────
    # Mainline it87 doesn't support this chip; the out-of-tree driver does.
    # Required for pwmconfig / fancontrol to see PWM controls.
    extraModulePackages = [ config.boot.kernelPackages.it87 ];
    kernelModules = [ "it87" ];

    # ── DDR5 SPD temp sensor breaks resume ──────────────────────────────────────
    # spd5118 (per-DIMM DDR5 temperature, kernel ≥6.11) fails its async resume
    # callback ("regmap_read failed: -6" / ENXIO) after suspend, which can stall
    # resume at a black screen. Per-DIMM RAM temps aren't used for anything here
    # (fan2go reads coretemp + it8628 only), so drop the module.
    blacklistedKernelModules = [ "spd5118" ];

    # ── HDMI hotplug flap guard (Philips FTV on HDMI-A-1) ──────────────────────
    # The TV drops the HDMI link entirely when powered off (not just idle), so the
    # kernel sees the connector removed→added repeatedly. Every event makes Hyprland
    # re-scan and re-apply the whole layout, which blinks the *other* screens on/off.
    # Force the connector permanently "on" (DRM_FORCE_ON) so the kernel stops probing
    # it — the output stays usable, and the Hyprland monitor line already pins a fixed
    # mode (3840x2160@60, see flake.nix) so there's no mode-guessing when the TV is off.
    kernelParams = [ "video=HDMI-A-1:e" ];

    # ── Bootloader ──────────────────────────────────────────────────────────────
    # Limine (themed menu + generation cap) comes from ../common/optional/limine.nix.
    loader.efi.canTouchEfiVariables = true;

    # Windows boots off the same ESP (its disk has no ESP of its own). systemd-boot
    # auto-detected it; Limine needs an explicit chainload entry.
    loader.limine.extraEntries = ''
      /Windows
          protocol: chainload
          path: boot():/EFI/Microsoft/Boot/bootmgfw.efi
    '';

    # btrfs "first mount" free-space-tree init creates a brief window where the
    # @nix subvolume is mounted but path lookups fail; retry instead of panicking.
    initrd.systemd.services.initrd-find-nixos-closure.serviceConfig = {
      Restart = "on-failure";
      RestartSec = "3";
      StartLimitBurst = 10;
      StartLimitIntervalSec = "60";
    };
  };

  # ── Networking ───────────────────────────────────────────────────────────────
  networking.hostName = "home-desktop";

  system.stateVersion = "24.11";
}
