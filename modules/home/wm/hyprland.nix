# modules/home/wm/hyprland.nix — Hyprland window manager configuration.
{ lib, config, ... }:
let
  cfg = config.custom.hm;
in
{
  options.custom.hm = {
    compositor = lib.mkOption {
      type = lib.types.enum [
        "hyprland"
        "none"
      ];
      default = "none";
      description = "Which Wayland compositor to configure for this user.";
    };

    monitors = {
      primary = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Primary monitor string, e.g. DP-3,2560x1440@165,2160x0,1";
      };
      primaryName = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Connector name of the primary monitor, e.g. DP-3. Used to pin workspaces.";
      };
      secondary = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Secondary monitor string, e.g. DP-2,3840x2160@60,0x0,1,transform,3";
      };
    };
  };

  config = lib.mkIf (cfg.compositor == "hyprland") {

    # ── Live-symlinked scripts (gaming-toggle, screenshot, lock, …) ───────────
    xdg.configFile."hypr/scripts".source = ../../../config/hypr-scripts;

    # ── Hypridle — replaces swayidle ───────────────────────────────────────────
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "hyprlock";
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = "hyprctl dispatch dpms on; pkill -x hyprlock; hyprlock";
        };
        listener = [
          {
            timeout = 300;
            on-timeout = "loginctl lock-session";
          }
          {
            timeout = 900;
            on-timeout = "systemctl suspend";
          }
        ];
      };
    };

    wayland.windowManager.hyprland = {
      enable = true;
      xwayland.enable = true;

      settings = {
        # ── Monitors ─────────────────────────────────────────────────────────
        monitor =
          lib.optional (cfg.monitors.secondary != null) cfg.monitors.secondary
          ++ lib.optional (cfg.monitors.primary != null) cfg.monitors.primary
          ++ lib.optional (cfg.monitors.primary == null) ",preferred,auto,1";

        workspace = lib.optionals (cfg.monitors.primaryName != "") [
          "1,  monitor:${cfg.monitors.primaryName}, default:true"
          "2,  monitor:${cfg.monitors.primaryName}"
          "3,  monitor:${cfg.monitors.primaryName}"
          "4,  monitor:${cfg.monitors.primaryName}"
          "5,  monitor:${cfg.monitors.primaryName}"
          "6,  monitor:${cfg.monitors.primaryName}"
          "7,  monitor:${cfg.monitors.primaryName}"
          "8,  monitor:${cfg.monitors.primaryName}"
          "9,  monitor:${cfg.monitors.primaryName}"
          "10, monitor:${cfg.monitors.primaryName}"
        ];

        # ── Startup ──────────────────────────────────────────────────────────
        "exec-once" = [
          "swww-daemon"
          "swww img ~/.config/hyprland/wallpaper.jpg --transition-type wipe --transition-fps 60"
          "swaync"
          "playerctld"
          "/run/current-system/sw/libexec/polkit-gnome-authentication-agent-1"
          "wl-paste --type text --watch cliphist store"
          "wl-paste --type image --watch cliphist store"
          "sleep 1 && nm-applet --indicator &"
          "sleep 1.5 && syncthingtray &"
          "gammastep"
        ];

        # ── Environment ───────────────────────────────────────────────────────
        env = [
          "XCURSOR_SIZE,24"
          "XCURSOR_THEME,Bibata-Modern-Classic"
          "WLR_NO_HARDWARE_CURSORS,1"
          "GTK_THEME,Gruvbox-Material-Dark"
          "__GLX_VENDOR_LIBRARY_NAME,nvidia"
          "GBM_BACKEND,nvidia-drm"
          "LIBVA_DRIVER_NAME,nvidia"
          "__GL_GSYNC_ALLOWED,1"
          "__GL_VRR_ALLOWED,1"
        ];

        # ── Input ─────────────────────────────────────────────────────────────
        input = {
          kb_layout = "us";
          follow_mouse = 1;
          sensitivity = 0;
          accel_profile = "flat";
          touchpad = {
            natural_scroll = true;
            disable_while_typing = true;
            "tap-to-click" = true;
          };
        };

        # ── General ───────────────────────────────────────────────────────────
        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
          layout = "dwindle";
          allow_tearing = true;
          "col.active_border" = "rgba(7daea3ee) rgba(d3869bee) 45deg";
          "col.inactive_border" = "rgba(3c3836aa)";
        };

        # ── Decoration ────────────────────────────────────────────────────────
        decoration = {
          rounding = 10;
          blur = {
            enabled = true;
            size = 3;
            passes = 1;
          };
          shadow = {
            enabled = true;
            range = 4;
            render_power = 3;
            color = "rgba(1a1a1aee)";
          };
        };

        # ── Animations ────────────────────────────────────────────────────────
        animations = {
          enabled = true;
          bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
          animation = [
            "windows,    1, 7, myBezier"
            "windowsOut, 1, 7, default, popin 80%"
            "border,     1, 10, default"
            "borderangle,1, 8, default"
            "fade,       1, 7, default"
            "workspaces, 1, 6, default"
          ];
        };

        # ── Layout ────────────────────────────────────────────────────────────
        dwindle = {
          preserve_split = true;
        };
        master.new_status = "master";

        # ── Gestures ──────────────────────────────────────────────────────────────
        gestures = {
          workspace_swipe_distance = 300;
        };

        # ── Misc ──────────────────────────────────────────────────────────────
        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          mouse_move_enables_dpms = true;
          key_press_enables_dpms = true;
          vrr = 2;
        };

        # ── Render ────────────────────────────────────────────────────────────
        # explicit_sync = 0 avoids "Failed to initialize semaphore for plane fence"
        # errors from nvidia-drm after suspend/resume (EAGAIN on atomic modeset).
        render = {
          explicit_sync = 2;
        };

        # ── Layer rules (layershell surfaces: waybar, swaync) ─────────────────────
        layerrule = [
          "blur on, match:namespace waybar"
          "ignore_alpha 0.0, match:namespace waybar"
          "blur on, match:namespace swaync-control-center"
          "ignore_alpha 0.0, match:namespace swaync-control-center"
          "blur on, match:namespace notifications"
          "ignore_alpha 0.0, match:namespace notifications"
        ];

        # ── Window rules ──────────────────────────────────────────────────────────
        windowrule = [
          # Gaming — allow tearing
          "immediate on, match:class ^(steam_app_)"
          "immediate on, match:class ^(Minecraft)"

          # Launchers
          "fullscreen on, match:class ^(steam)$, match:title ^(Steam Big Picture Mode)$"
          "workspace 10 silent, match:class ^(lutris)$"
          "workspace 10 silent, match:class ^(steam)$"

          # Float
          "float on, match:class ^(pavucontrol)$"
          "float on, match:class ^(nm-connection-editor)$"
          "float on, match:class ^(blueman-manager)$"
          "float on, match:title ^(Picture-in-Picture)$"

          # Opacity
          "opacity 0.90 0.90, match:class ^(kitty)$"
          "opacity 1.0 override 1.0 override, match:class ^(firefox)$"
          "opacity 1.0 override 1.0 override, match:class ^(chromium)$"
          "opacity 1.0 override 1.0 override, match:class ^(google-chrome)$"

          # Workspace assignments
          "workspace 1, match:class ^(firefox)$"
          "workspace 2, match:class ^(Code)$"
          "workspace 3, match:class ^(kitty)$"
          "workspace 4, match:class ^(discord)$"
          "workspace 5, match:class ^(Spotify)$"
        ];

        # ── Keybindings ───────────────────────────────────────────────────────
        "$mainMod" = "SUPER";

        bind = [
          # Apps
          "$mainMod, Return, exec, kitty"
          "$mainMod, D, exec, fuzzel"
          "$mainMod, E, exec, thunar"
          "$mainMod, B, exec, google-chrome-stable"

          # Window management
          "$mainMod, Q, killactive,"
          "$mainMod SHIFT, Q, exit,"
          "$mainMod, V, togglefloating,"
          "$mainMod, P, pseudo,"
          "$mainMod, T, layoutmsg, togglesplit"
          "$mainMod, F, fullscreen, 0"
          "$mainMod SHIFT, F, fullscreen, 1"

          # Move focus — vim
          "$mainMod, h, movefocus, l"
          "$mainMod, l, movefocus, r"
          "$mainMod, k, movefocus, u"
          "$mainMod, j, movefocus, d"

          # Move focus — arrows
          "$mainMod, left,  movefocus, l"
          "$mainMod, right, movefocus, r"
          "$mainMod, up,    movefocus, u"
          "$mainMod, down,  movefocus, d"

          # Move windows — vim
          "$mainMod SHIFT, h, movewindow, l"
          "$mainMod SHIFT, l, movewindow, r"
          "$mainMod SHIFT, k, movewindow, u"
          "$mainMod SHIFT, j, movewindow, d"

          # Move windows — arrows
          "$mainMod SHIFT, left,  movewindow, l"
          "$mainMod SHIFT, right, movewindow, r"
          "$mainMod SHIFT, up,    movewindow, u"
          "$mainMod SHIFT, down,  movewindow, d"

          # Resize — vim
          "$mainMod CTRL, h, resizeactive, -50 0"
          "$mainMod CTRL, l, resizeactive, 50 0"
          "$mainMod CTRL, k, resizeactive, 0 -50"
          "$mainMod CTRL, j, resizeactive, 0 50"

          # Resize — arrows
          "$mainMod CTRL, left,  resizeactive, -50 0"
          "$mainMod CTRL, right, resizeactive, 50 0"
          "$mainMod CTRL, up,    resizeactive, 0 -50"
          "$mainMod CTRL, down,  resizeactive, 0 50"

          # Workspaces
          "$mainMod, 1, workspace, 1"
          "$mainMod, 2, workspace, 2"
          "$mainMod, 3, workspace, 3"
          "$mainMod, 4, workspace, 4"
          "$mainMod, 5, workspace, 5"
          "$mainMod, 6, workspace, 6"
          "$mainMod, 7, workspace, 7"
          "$mainMod, 8, workspace, 8"
          "$mainMod, 9, workspace, 9"
          "$mainMod, 0, workspace, 10"

          # Move to workspace
          "$mainMod SHIFT, 1, movetoworkspace, 1"
          "$mainMod SHIFT, 2, movetoworkspace, 2"
          "$mainMod SHIFT, 3, movetoworkspace, 3"
          "$mainMod SHIFT, 4, movetoworkspace, 4"
          "$mainMod SHIFT, 5, movetoworkspace, 5"
          "$mainMod SHIFT, 6, movetoworkspace, 6"
          "$mainMod SHIFT, 7, movetoworkspace, 7"
          "$mainMod SHIFT, 8, movetoworkspace, 8"
          "$mainMod SHIFT, 9, movetoworkspace, 9"
          "$mainMod SHIFT, 0, movetoworkspace, 10"

          # Scroll workspaces
          "$mainMod, mouse_down, workspace, e+1"
          "$mainMod, mouse_up,   workspace, e-1"

          # Scratchpad
          "$mainMod, S, togglespecialworkspace, magic"
          "$mainMod SHIFT, S, movetoworkspace, special:magic"

          # System
          "$mainMod, L, exec, hyprlock"
          "$mainMod SHIFT, L, exec, systemctl suspend"
          "$mainMod SHIFT, E, exec, wlogout -p layer-shell"
          "$mainMod, N, exec, swaync-client -t -sw"
          "$mainMod SHIFT, V, exec, cliphist list | fuzzel -d | cliphist decode | wl-copy"

          # Screenshots
          ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
          "SHIFT, Print, exec, grim - | wl-copy"
          "$mainMod, Print, exec, grim -g \"$(slurp)\" ~/Pictures/Screenshots/$(date +%Y%m%d-%H%M%S).png"

          # Volume
          ", XF86AudioRaiseVolume, exec, pamixer -i 5"
          ", XF86AudioLowerVolume, exec, pamixer -d 5"
          ", XF86AudioMute,        exec, pamixer -t"

          # Brightness
          ", XF86MonBrightnessUp,   exec, brightnessctl set +10%"
          ", XF86MonBrightnessDown, exec, brightnessctl set 10%-"

          # Media
          ", XF86AudioPlay,  exec, playerctl play-pause"
          ", XF86AudioNext,  exec, playerctl next"
          ", XF86AudioPrev,  exec, playerctl previous"

          # Gaming toggle
          "$mainMod SHIFT, G, exec, ~/.config/hypr/scripts/gaming-toggle.sh"
        ];

        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];
      };
    };
  };
}
