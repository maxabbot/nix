# modules/home/theme.nix — Gruvbox Material Dark theming.
{ pkgs, config, lib, ... }:
{
  # ── GTK ───────────────────────────────────────────────────────────────────────
  gtk = {
    enable = true;

    theme = {
      name = "Gruvbox-Material-Dark";
      package = pkgs.gruvbox-material-gtk-theme or pkgs.gruvbox-dark-gtk;
    };

    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
    };

    font = {
      name = "Inter";
      size = 11;
      package = pkgs.inter;
    };

    gtk3 = {
      extraConfig = {
        gtk-application-prefer-dark-theme = 1;
        gtk-decoration-layout = "close,minimize,maximize:";
      };
    };

    gtk4 = {
      extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
      theme = {
        name = "Gruvbox-Material-Dark";
        package = pkgs.gruvbox-material-gtk-theme or pkgs.gruvbox-dark-gtk;
      };
    };
  };

  # ── XDG color scheme (used by Zed, Electron, and other portal-aware apps) ────
  dconf.settings."org/freedesktop/appearance".color-scheme = 1; # 1 = dark

  # ── Qt (qt6ct) ────────────────────────────────────────────────────────────────
  qt = {
    enable = true;
    platformTheme.name = "qt6ct";
  };

  # ── Cursor (for non-GTK apps and X11) ─────────────────────────────────────────
  home.file.".icons/default/index.theme".text = ''
    [Icon Theme]
    Name=Default
    Comment=Default Cursor Theme
    Inherits=Bibata-Modern-Classic
  '';

  # ── Session variables ─────────────────────────────────────────────────────────
  home.sessionVariables = {
    GTK_THEME = "Gruvbox-Material-Dark";
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    GDK_SCALE = "1";
    # Electron apps — native Wayland rendering (VSCode, Discord, Obsidian, etc.)
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    # Firefox native Wayland
    MOZ_ENABLE_WAYLAND = "1";
    # Java AWT — prevents blank windows in IntelliJ / AWT apps on Wayland
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  # ── XDG mime defaults ─────────────────────────────────────────────────────────
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/plain" = [ "dev.zed.Zed.desktop" ];
      "text/html" = [ "google-chrome.desktop" ];
      "application/pdf" = [ "org.pwmt.zathura.desktop" ];
      "image/png" = [ "imv.desktop" ];
      "image/jpeg" = [ "imv.desktop" ];
      "image/gif" = [ "imv.desktop" ];
      "image/svg+xml" = [ "imv.desktop" ];
      "video/mp4" = [ "mpv.desktop" ];
      "video/mkv" = [ "mpv.desktop" ];
      "video/webm" = [ "mpv.desktop" ];
      "audio/mpeg" = [ "mpv.desktop" ];
      "audio/flac" = [ "mpv.desktop" ];
      "inode/directory" = [ "thunar.desktop" ];
      "x-scheme-handler/http" = [ "google-chrome.desktop" ];
      "x-scheme-handler/https" = [ "google-chrome.desktop" ];
    };
  };
}
