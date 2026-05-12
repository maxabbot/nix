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

    # The repo is edited from Windows (OneDrive), so the +x bit isn't preserved
    # in git. Mark the hypr-scripts shell files executable on every rebuild so
    # QML click handlers in TopBar can exec qs_manager.sh and friends directly.
    # Runs as root because /etc/nixos is root-owned after `sudo git pull`.
    system.activationScripts.chmodHyprScripts.text = ''
      if [ -d /etc/nixos/config/hypr-scripts ]; then
        ${pkgs.findutils}/bin/find /etc/nixos/config/hypr-scripts \
          -type f -name '*.sh' -exec chmod +x {} +
      fi
    '';

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
        # Wayland tools
        grim
        slurp
        awww
        swaynotificationcenter
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

        # Dynamic color theming
        matugen

        # Quickshell top bar + required Qt6 modules
        quickshell
        qt6.qtmultimedia
        qt6.qt5compat
        qt6.qtwebsockets
        qt6.qtwebengine

        # Audio tools
        pavucontrol
        pamixer

        # Volume/brightness OSD
        swayosd

        # Audio visualizer
        cava

        # Idle management
        hypridle

        # Shell utilities used by quickshell scripts
        socat
        acpi
        iw
        bluez
        bc

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
