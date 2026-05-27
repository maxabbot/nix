# modules/home/theme.nix — Supplementary theming on top of Stylix.
# Stylix owns: GTK theme/font/cursor, Qt, base16 colours, pointer cursor.
# We own: icon theme, dark-mode prefs, Wayland/Electron env vars, MIME apps.
{ pkgs, ... }:
{
  # ── Icons (Stylix does not manage icon themes) ────────────────────────────────
  gtk = {
    enable = true;

    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
      gtk-decoration-layout = "close,minimize,maximize:";
    };

    gtk4 = {
      theme = null;
      extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
    };
  };

  # ── Session variables ─────────────────────────────────────────────────────────
  home.sessionVariables = {
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    GDK_SCALE = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    MOZ_ENABLE_WAYLAND = "1";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  # ── XDG MIME defaults ─────────────────────────────────────────────────────────
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
