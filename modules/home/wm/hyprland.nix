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

    # ── Quickshell scripts — symlinked live from the repo so scripts stay mutable
    home.file.".config/hypr/scripts".source =
      config.lib.file.mkOutOfStoreSymlink "/etc/nixos/config/hypr-scripts";

    # ── Hypridle — replaces swayidle ───────────────────────────────────────────
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "hyprlock";
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = "hyprctl dispatch dpms on";
        };
        listener = [
          {
            timeout = 300;
            on-timeout = "loginctl lock-session";
          }
          {
            timeout = 600;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
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

      # Declare Gruvbox fallback colors, then source matugen-generated overrides.
      # Re-declare general borders so $active_border/$inactive_border take effect.
      extraConfig = ''
        $active_border = rgba(7daea3ee) rgba(d3869bee) 45deg
        $inactive_border = rgba(3c3836aa)
        source = ~/.config/hypr/colors.conf

        general {
          col.active_border = $active_border
          col.inactive_border = $inactive_border
        }
      '';

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
          "playerctld"
          "quickshell -p ~/.config/hypr/scripts/quickshell/Shell.qml"
          "swayosd-server"
          "swaync"
          "/run/current-system/sw/libexec/polkit-gnome-authentication-agent-1"
          "wl-paste --type text --watch cliphist store"
          "wl-paste --type image --watch cliphist store"
          "sleep 0.5 && copyq --start-server &"
          "sleep 1 && nm-applet --indicator &"
          "sleep 1.5 && syncthingtray &"
          "gammastep"
          "~/.config/hypr/scripts/settings_watcher.sh &"
          "~/.config/hypr/scripts/volume_listener.sh"
          "python3 ~/.config/hypr/scripts/quickshell/focustime/focus_daemon.py &"
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

        # ── Window rules ──────────────────────────────────────────────────────────
        windowrule = [
          # Gaming — immediate/tearing
          "immediate true, match:class ^(steam_app_)(.*)$"
          "immediate true, match:class ^(cs2)$"
          "immediate true, match:class ^(dota2)$"
          "immediate true, match:class ^(Minecraft)(.*)$"

          # Launchers
          "fullscreen true, match:class ^(steam)$, match:title ^(Steam Big Picture)$"
          "workspace 10, match:class ^(lutris)$"
          "workspace 10, match:class ^(steam)$"

          # Float
          "float true, match:class ^(pavucontrol)$"
          "float true, match:class ^(nm-connection-editor)$"
          "float true, match:class ^(blueman-manager)$"
          "float true, match:title ^(Picture-in-Picture)$"

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
          "$mainMod, E, exec, thunar"
          "$mainMod, B, exec, google-chrome-stable"

          # Quickshell panel toggles
          "$mainMod, D, exec, ~/.config/hypr/scripts/qs_manager.sh toggle applauncher"
          "$mainMod, C, exec, ~/.config/hypr/scripts/qs_manager.sh toggle clipboard"
          "$mainMod, M, exec, ~/.config/hypr/scripts/qs_manager.sh toggle monitors"
          "$mainMod, N, exec, ~/.config/hypr/scripts/qs_manager.sh toggle network"
          "$mainMod, W, exec, ~/.config/hypr/scripts/qs_manager.sh toggle wallpaper"

          # Window management
          "$mainMod, Q, killactive,"
          "$mainMod SHIFT, Q, exit,"
          "$mainMod, V, togglefloating,"
          "$mainMod, P, pseudo,"
          "$mainMod, J, layoutmsg, togglesplit"
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

          # Screenshots
          ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
          "SHIFT, Print, exec, grim - | wl-copy"
          "$mainMod, Print, exec, grim -g \"$(slurp)\" ~/Pictures/Screenshots/$(date +%Y%m%d-%H%M%S).png"

          # Media
          ", XF86AudioPlay,  exec, playerctl play-pause"
          ", XF86AudioNext,  exec, playerctl next"
          ", XF86AudioPrev,  exec, playerctl previous"

          # Volume via swayosd
          ", XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise"
          ", XF86AudioLowerVolume, exec, swayosd-client --output-volume lower"
          ", XF86AudioMute,        exec, swayosd-client --output-volume mute-toggle"
          ", XF86AudioMicMute,     exec, swayosd-client --input-volume mute-toggle"

          # Brightness via swayosd
          ", XF86MonBrightnessUp,   exec, swayosd-client --brightness raise"
          ", XF86MonBrightnessDown, exec, swayosd-client --brightness lower"

          # Caps lock indicator via swayosd
          ", Caps_Lock, exec, sleep 0.1 && swayosd-client --caps-lock"

          # Gaming toggle
          "$mainMod SHIFT, G, exec, ~/.config/hypr/gaming-toggle.sh"
        ];

        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];
      };
    };
  };
}
