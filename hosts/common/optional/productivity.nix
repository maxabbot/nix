{
  pkgs,
  inputs,
  zen-browser,
  ...
}:
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

  programs.silentSDDM.enable = true;

  # ── Wayland session variables ─────────────────────────────────────────────────
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  environment.systemPackages = with pkgs; [
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
