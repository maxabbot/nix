# modules/nixos/productivity.nix — Desktop environment, audio, apps, and browsers.
# Mirrors system/roles/productivity from the Arch Ansible layer.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.productivity;
in
{
  options.custom.productivity = {
    enable = lib.mkEnableOption "productivity desktop stack";

    compositor = lib.mkOption {
      type = lib.types.enum [
        "hyprland"
        "sway"
      ];
      default = "hyprland";
      description = "Wayland compositor to configure at the system level.";
    };

    creativeApps.enable = lib.mkEnableOption "creative suite (GIMP, Inkscape, Krita)";
    streamingTools.enable = lib.mkEnableOption "streaming / remote desktop tools (OBS, Shotcut, RustDesk)";
    secondaryBrowsers.enable = lib.mkEnableOption "secondary browsers (Zen)";
    communicationApps.enable = lib.mkEnableOption "extra communication apps (Slack, Discord, Zoom)";
  };

  config = lib.mkIf cfg.enable {
    # ── Hyprland ───────────────────────────────────────────────────────────────
    programs.hyprland = lib.mkIf (cfg.compositor == "hyprland") {
      enable = true;
      xwayland.enable = true;
    };

    # ── Sway ───────────────────────────────────────────────────────────────────
    programs.sway = lib.mkIf (cfg.compositor == "sway") {
      enable = true;
      wrapperFeatures.gtk = true;
    };

    # ── Display manager (SDDM) ─────────────────────────────────────────────────
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };

    # ── PipeWire audio stack ───────────────────────────────────────────────────
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };

    # Disable PulseAudio — PipeWire replaces it
    hardware.pulseaudio.enable = false;

    # ── XDG portals ────────────────────────────────────────────────────────────
    xdg.portal.extraPortals =
      lib.optionals (cfg.compositor == "hyprland") [
        pkgs.xdg-desktop-portal-hyprland
      ]
      ++ lib.optionals (cfg.compositor == "sway") [
        pkgs.xdg-desktop-portal-wlr
      ];

    # ── Wayland session variables ──────────────────────────────────────────────
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      WLR_NO_HARDWARE_CURSORS = "1";
      MOZ_ENABLE_WAYLAND = "1";
    };

    # ── Syncthing ──────────────────────────────────────────────────────────────
    services.syncthing = {
      enable = true;
      user = config.custom.base.username;
      dataDir = "/home/${config.custom.base.username}";
      configDir = "/home/${config.custom.base.username}/.config/syncthing";
    };

    # ── Flatpak ────────────────────────────────────────────────────────────────
    services.flatpak.enable = true;

    # ── System packages ────────────────────────────────────────────────────────
    environment.systemPackages =
      with pkgs;
      [
        # Wayland tools
        grim
        slurp
        swww
        swayidle
        swaynotificationcenter
        wl-clipboard
        wl-paste
        cliphist
        fuzzel
        gammastep
        wlogout
        nwg-look
        hyprlock
        waybar
        playerctl
        brightnessctl
        grimblast

        # Audio
        pavucontrol

        # File manager
        xfce.thunar
        xfce.thunar-archive-plugin
        file-roller

        # Office / documents
        libreoffice-fresh
        xournalpp
        zathura
        zathura-pdf-mupdf
        calibre
        pdfarranger
        masterpdfeditor
        onlyoffice-bin

        # Communication
        thunderbird
        element-desktop

        # Browsers
        google-chrome

        # Notes / passwords
        obsidian
        bitwarden-desktop

        # Media
        vlc
        mpv
        imv
        mpvpaper

        # Cloud / sync
        rclone

        # Monitoring / hardware
        nvtop
        openrgb-with-all-plugins
        glances

        # Security / backup
        veracrypt

        # Desktop helpers
        kvantum
        papirus-icon-theme
        foot
        syncthingtray

        # Terminal file manager / misc
        yazi
      ]
      ++ lib.optionals cfg.creativeApps.enable [
        gimp
        inkscape
        krita
      ]
      ++ lib.optionals cfg.streamingTools.enable [
        obs-studio
        shotcut
        rustdesk
        gpu-screen-recorder
        losslesscut-bin
      ]
      ++ lib.optionals cfg.secondaryBrowsers.enable [
        zen-browser
      ]
      ++ lib.optionals cfg.communicationApps.enable [
        slack
        discord
        zoom-us
      ];

    # ── OpenRGB udev rules ──────────────────────────────────────────────────────
    services.udev.packages = [ pkgs.openrgb-with-all-plugins ];

    # ── Thunar (GVFS for remote / archive mounts) ──────────────────────────────
    services.gvfs.enable = true;
    services.tumbler.enable = true;
  };
}
