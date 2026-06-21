{
  config,
  pkgs,
  inputs,
  zen-browser,
  ...
}:
let
  inherit (config.custom.base) username;
in
{
  imports = [ inputs.silentSDDM.nixosModules.default ];

  # ── Hyprland ──────────────────────────────────────────────────────────────────
  # Using nixpkgs' hyprland module and package avoids referencing the flake's
  # source tarball at evaluation time (which breaks nix flake check).
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  services = {
    # ── Display manager (SDDM via SilentSDDM) ──────────────────────────────────
    # silentSDDM module handles enable/theme/extraPackages/QML2_IMPORT_PATH.
    # Do NOT use sugar-dark — it depends on Qt5 QtGraphicalEffects which
    # doesn't exist in Qt6 (SDDM 0.21+). Stylix has no SDDM target.
    # Do NOT set wayland.compositor — the nixpkgs default ("weston") handles
    # mouse/keyboard correctly in VMs; kwin is GPU-heavy and breaks input.
    # kdePackages.breeze must be in extraPackages so breeze_cursors is findable
    # on disk — silentSDDM's module only ships its own propagatedBuildInputs.
    displayManager.sddm.extraPackages = [ pkgs.kdePackages.breeze ];
    displayManager.sddm.settings.Theme = {
      CursorTheme = "breeze_cursors";
      CursorSize = "24";
    };
    # ── PipeWire audio stack ────────────────────────────────────────────────────
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };
    pulseaudio.enable = false;
    # ── Syncthing ───────────────────────────────────────────────────────────────
    syncthing = {
      enable = true;
      user = username;
      dataDir = "/home/${username}";
      configDir = "/home/${username}/.config/syncthing";
    };
    # ── Flatpak ─────────────────────────────────────────────────────────────────
    flatpak.enable = true;
    # ── Misc services ───────────────────────────────────────────────────────────
    udev.packages = [ pkgs.openrgb-with-all-plugins ];
    gvfs.enable = true;
    tumbler.enable = true;
  };

  programs.silentSDDM = {
    enable = true;
    theme = "gruvbox";

    backgrounds = {
      wallpaper = ../../../config/sddm/leaves-wall.png;
    };

    settings = {
      # ── Background — gruvbox preset has use-background-color = true which
      # overrides the image; must explicitly disable it here.
      "LoginScreen" = {
        background = "leaves-wall.png";
        use-background-color = false;
        blur = 8;
      };
      "LockScreen" = {
        background = "leaves-wall.png";
        use-background-color = false;
        blur = 28;
      };

      # ── Login panel — right side so wallpaper is visible ──────────────────
      "LoginScreen.LoginArea" = {
        position = "right";
      };

      # ── Lock screen clock — 24h ───────────────────────────────────────────
      "LockScreen.Clock" = {
        format = "HH:mm";
      };
      "LockScreen.Date" = {
        locale = "en_NZ";
      };

    };
  };

  # NVIDIA hardware cursor planes sometimes fail silently in KWin/Wayland;
  # force software cursor so the pointer is always visible in the greeter.
  # Harmless on Intel/Mesa (software cursor is the only path there anyway).
  systemd.services.sddm.environment.KWIN_FORCE_SW_CURSOR = "1";

  # KWin reads cursor theme/size from kcminputrc, not from sddm.conf [Theme].
  system.activationScripts.sddmCursorConfig = {
    deps = [ "users" ];
    text = ''
      mkdir -p /var/lib/sddm/.config
      printf '[Mouse]\ncursorTheme=breeze_cursors\ncursorSize=24\n' \
        > /var/lib/sddm/.config/kcminputrc
      chown sddm:sddm /var/lib/sddm/.config/kcminputrc
    '';
  };

  # ── Wayland session variables ─────────────────────────────────────────────────
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  environment.systemPackages = with pkgs; [
    grim
    slurp
    satty
    zbar
    awww # wallpaper daemon — NOT "swww"
    wl-clipboard
    cliphist
    wlogout
    nwg-look
    hyprlock
    playerctl
    brightnessctl
    grimblast
    pavucontrol
    pamixer
    pulseaudio
    swayosd
    hypridle
    thunar
    thunar-archive-plugin
    file-roller
    libreoffice-fresh
    rnote
    zathura
    calibre
    pdfarranger
    masterpdfeditor
    onlyoffice-desktopeditors
    thunderbird
    element-desktop
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    obsidian
    bitwarden-desktop
    vlc
    mpv
    imv
    mpvpaper
    rclone
    nvtopPackages.full
    openrgb-with-all-plugins
    glances
    veracrypt
    kdePackages.qtstyleplugin-kvantum
    papirus-icon-theme
    yazi
    quickshell
  ];

}
