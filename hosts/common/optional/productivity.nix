{
  pkgs,
  zen-browser,
  ...
}:
{
  # ── Hyprland ──────────────────────────────────────────────────────────────────
  # Using nixpkgs' hyprland module and package avoids referencing the flake's
  # source tarball at evaluation time (which breaks nix flake check).
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  services = {
    # ── Display manager (SDDM) ──────────────────────────────────────────────────
    # sddm-astronaut is Qt6-native (uses kdePackages). Do NOT use sugar-dark —
    # it depends on libsForQt5.qtgraphicaleffects which is Qt5-only and
    # incompatible with SDDM 0.21+ (Qt6). Stylix has no SDDM target.
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      wayland.compositor = "kwin";
      theme = "sddm-astronaut-theme";
      extraPackages = with pkgs; [
        sddm-astronaut
        kdePackages.qtsvg
        kdePackages.qtmultimedia
        kdePackages.qtvirtualkeyboard
      ];
      settings.Theme = {
        CursorTheme = "breeze_cursors";
        CursorSize = "24";
      };
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
      user = "max";
      dataDir = "/home/max";
      configDir = "/home/max/.config/syncthing";
    };
    # ── Flatpak ─────────────────────────────────────────────────────────────────
    flatpak.enable = true;
    # ── Misc services ───────────────────────────────────────────────────────────
    udev.packages = [ pkgs.openrgb-with-all-plugins ];
    gvfs.enable = true;
    tumbler.enable = true;
  };

  # ── Wayland session variables ─────────────────────────────────────────────────
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # ── System packages ───────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    sddm-astronaut
    grim
    slurp
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
    foot
    syncthingtray
    swaynotificationcenter
    yazi
  ];

}
