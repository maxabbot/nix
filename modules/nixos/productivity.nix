# modules/nixos/productivity.nix — Desktop environment, audio, and productivity apps.
{
  config,
  lib,
  pkgs,
  zen-browser,
  ...
}:
let
  cfg = config.custom.productivity;
in
{
  options.custom.productivity = {
    enable = lib.mkEnableOption "productivity desktop stack";

    creativeApps.enable = lib.mkEnableOption "creative suite (GIMP, Inkscape, Krita)";
    streamingTools.enable = lib.mkEnableOption "streaming / remote desktop tools (OBS, Shotcut, RustDesk)";
    secondaryBrowsers.enable = lib.mkEnableOption "secondary browsers (Chrome)";
    communicationApps.enable = lib.mkEnableOption "extra communication apps (Slack, Discord, Zoom)";
  };

  config = lib.mkIf cfg.enable {
    # ── Hyprland ───────────────────────────────────────────────────────────────
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    # ── Display manager (SDDM) ─────────────────────────────────────────────────
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      wayland.compositor = "kwin";
      theme = "sugar-dark";
      extraPackages = [ pkgs.sddm-sugar-dark ];
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
    services.pulseaudio.enable = false;

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
        sddm-sugar-dark
        # Wayland tools
        grim
        slurp
        awww
        wl-clipboard
        cliphist
        wlogout
        nwg-look
        hyprlock
        # fuzzel + waybar: provided by HM (programs.fuzzel / programs.waybar)
        # gammastep: provided by HM (services.gammastep)
        playerctl
        brightnessctl
        grimblast

        # Audio tools
        pavucontrol
        pamixer

        # Idle management
        hypridle

        # File manager
        thunar
        thunar-archive-plugin
        file-roller

        # Office / documents
        libreoffice-fresh
        xournalpp
        zathura
        calibre
        pdfarranger
        masterpdfeditor
        onlyoffice-desktopeditors

        # Communication
        thunderbird
        element-desktop

        # Browsers
        zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default

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
        nvtopPackages.full
        openrgb-with-all-plugins
        glances

        # Security / backup
        veracrypt

        # Desktop helpers
        kdePackages.qtstyleplugin-kvantum
        papirus-icon-theme
        foot
        syncthingtray
        swaynotificationcenter

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
        google-chrome
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
