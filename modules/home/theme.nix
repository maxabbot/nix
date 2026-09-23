# modules/home/theme.nix — Supplementary theming on top of Stylix.
# Stylix owns: GTK theme/font/cursor, Qt, base16 colours, pointer cursor, and
# the icon theme (stylix.icons in hosts/common/optional/stylix.nix — it feeds
# both the GTK setting and qt5ct/qt6ct's icon_theme, which a hand-rolled
# gtk.iconTheme here could not reach).
# We own: dark-mode prefs, Wayland/Electron env vars, MIME apps, Thunar's
# translucency.
# Everything here is GUI-only, so the whole module is gated on a compositor
# being configured.
{
  lib,
  config,
  ...
}:
let
  palette = import ../../config/stylix/palette.nix;
in
{
  config = lib.mkIf (config.custom.hm.compositor != "none") {
    gtk = {
      enable = true;

      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
        gtk-decoration-layout = "close,minimize,maximize:";
      };

      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
    };

    # ── Translucent Thunar ───────────────────────────────────────────────────────
    # The window background carries the alpha (0.75, like kitty/fuzzel) and
    # every pane on top of it goes transparent, so the layers don't stack
    # back up to near-solid. GTK3 drops its Wayland opaque region once the
    # background has alpha, and Hyprland blurs behind it. Selected rows keep
    # their solid highlight via :not(:selected). User gtk.css outranks the
    # theme regardless of specificity, so :backdrop (unfocused) stays
    # translucent too. Stylix owns gtk.css, hence its extraCss hook rather
    # than gtk.gtk3.extraCss.
    stylix.targets.gtk.extraCss = ''
      window.thunar { background-color: alpha(${palette.bg0}, 0.75); }
      window.thunar .view:not(:selected),
      window.thunar iconview:not(:selected),
      window.thunar treeview:not(:selected),
      window.thunar row:not(:selected),
      window.thunar scrolledwindow,
      window.thunar viewport,
      window.thunar placessidebar,
      window.thunar .sidebar,
      window.thunar list,
      window.thunar toolbar,
      window.thunar .toolbar,
      window.thunar headerbar,
      window.thunar menubar,
      window.thunar statusbar,
      window.thunar paned,
      window.thunar notebook,
      window.thunar notebook > stack,
      window.thunar notebook > header {
        background-color: transparent;
        background-image: none;
      }
    '';

    # ── Session variables ─────────────────────────────────────────────────────────
    home.sessionVariables = {
      QT_AUTO_SCREEN_SCALE_FACTOR = "1";
      QT_QPA_PLATFORM = "wayland;xcb";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      GDK_SCALE = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      # MOZ_ENABLE_WAYLAND is set system-wide in productivity.nix
      _JAVA_AWT_WM_NONREPARENTING = "1";
    };

    # ── XDG MIME defaults ─────────────────────────────────────────────────────────
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "text/plain" = [ "dev.zed.Zed.desktop" ];
        "text/html" = [ "zen-beta.desktop" ];
        "application/pdf" = [ "org.pwmt.zathura.desktop" ];
        "image/png" = [ "imv.desktop" ];
        "image/jpeg" = [ "imv.desktop" ];
        "image/gif" = [ "imv.desktop" ];
        "image/svg+xml" = [ "imv.desktop" ];
        "video/mp4" = [ "mpv.desktop" ];
        "video/x-matroska" = [ "mpv.desktop" ];
        "video/webm" = [ "mpv.desktop" ];
        "audio/mpeg" = [ "mpv.desktop" ];
        "audio/flac" = [ "mpv.desktop" ];
        "inode/directory" = [ "thunar.desktop" ];
        "x-scheme-handler/http" = [ "zen-beta.desktop" ];
        "x-scheme-handler/https" = [ "zen-beta.desktop" ];
      };
    };
  };
}
