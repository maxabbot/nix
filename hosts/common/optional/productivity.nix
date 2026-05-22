{
  pkgs,
  inputs,
  zen-browser,
  ...
}:
{
  imports = [ inputs.hyprland.nixosModules.default ];

  # ── Hyprland ──────────────────────────────────────────────────────────────────
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  home-manager.sharedModules = [ inputs.hyprland.homeManagerModules.default ];

  # ── Display manager (SDDM) ────────────────────────────────────────────────────
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    wayland.compositor = "kwin";
    theme = "sugar-dark";
    extraPackages = [
      pkgs.sddm-sugar-dark
      pkgs.kdePackages.breeze
      pkgs.kdePackages.qtsvg
      pkgs.kdePackages.qtmultimedia
    ];
    settings.Theme = {
      CursorTheme = "breeze_cursors";
      CursorSize = "24";
    };
  };

  # ── PipeWire audio stack ──────────────────────────────────────────────────────
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };
  services.pulseaudio.enable = false;

  # ── Wayland session variables ─────────────────────────────────────────────────
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # ── Syncthing ─────────────────────────────────────────────────────────────────
  services.syncthing = {
    enable = true;
    user = "max";
    dataDir = "/home/max";
    configDir = "/home/max/.config/syncthing";
  };

  # ── Flatpak ───────────────────────────────────────────────────────────────────
  services.flatpak.enable = true;

  # ── System packages ───────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    sddm-sugar-dark
    grim
    slurp
    awww
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

  services.udev.packages = [ pkgs.openrgb-with-all-plugins ];
  services.gvfs.enable = true;
  services.tumbler.enable = true;
}
