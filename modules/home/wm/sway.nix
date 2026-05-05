# modules/home/wm/sway.nix — Sway window manager configuration.
# Translated from user/dot_config/sway/config.tmpl.
# Only activates when custom.hm.compositor == "sway".
{ lib, config, ... }:
let
  cfg = config.custom.hm;
in {
  config = lib.mkIf (cfg.compositor == "sway") {
    wayland.windowManager.sway = {
      enable               = true;
      wrapperFeatures.gtk  = true;
      xwayland             = true;

      config = {
        modifier  = "Mod4";
        terminal  = "kitty";
        menu      = "fuzzel";

        # ── Font ─────────────────────────────────────────────────────────────
        fonts = {
          names = [ "JetBrainsMono Nerd Font" ];
          size  = 10.0;
        };

        # ── Gaps ─────────────────────────────────────────────────────────────
        gaps = {
          inner = 5;
          outer = 10;
        };

        # ── Borders ──────────────────────────────────────────────────────────
        defaultBorderSize    = 2;
        defaultFloatingBorder = 2;

        # ── Colors — Gruvbox Material Dark ────────────────────────────────────
        colors = {
          focused         = { border = "#7daea3"; background = "#282828"; text = "#d4be98"; indicator = "#7daea3"; childBorder = "#7daea3"; };
          focusedInactive = { border = "#3c3836"; background = "#282828"; text = "#d4be98"; indicator = "#3c3836"; childBorder = "#3c3836"; };
          unfocused       = { border = "#3c3836"; background = "#282828"; text = "#7c6f64"; indicator = "#3c3836"; childBorder = "#3c3836"; };
          urgent          = { border = "#ea6962"; background = "#282828"; text = "#d4be98"; indicator = "#ea6962"; childBorder = "#ea6962"; };
        };

        # ── Output ───────────────────────────────────────────────────────────
        output = {
          "*" = { bg = "~/.config/sway/wallpaper.jpg fill"; adaptive_sync = "on"; };
        } // lib.optionalAttrs (cfg.monitors.primary != null) (
          let parts = lib.splitString " " cfg.monitors.primary;
          in { "${builtins.head parts}" = { "${lib.elemAt parts 1}" = lib.concatStringsSep " " (lib.drop 2 parts); }; }
        );

        # ── Input ────────────────────────────────────────────────────────────
        input = {
          "type:keyboard" = {
            xkb_layout   = "us";
            repeat_delay = "300";
            repeat_rate  = "50";
          };
          "type:pointer" = {
            accel_profile = "flat";
            pointer_accel = "0";
          };
          "type:touchpad" = {
            dwt              = "enabled";
            tap              = "enabled";
            natural_scroll   = "enabled";
            middle_emulation = "enabled";
          };
        };

        # ── Key bindings ──────────────────────────────────────────────────────
        keybindings =
          let m = "Mod4";
          in {
            # Apps
            "${m}+Return"         = "exec kitty";
            "${m}+d"              = "exec fuzzel";
            "${m}+e"              = "exec thunar";
            "${m}+b"              = "exec google-chrome-stable";

            # Window management
            "${m}+q"              = "kill";
            "${m}+f"              = "fullscreen";
            "${m}+v"              = "floating toggle";
            "${m}+space"          = "focus mode_toggle";
            "${m}+t"              = "splith";
            "${m}+Shift+t"        = "splitv";
            "${m}+Shift+r"        = "reload";
            "${m}+Shift+q"        = "exec swaynag -t warning -m 'Exit Sway?' -B 'Yes' 'swaymsg exit'";

            # Focus — vim
            "${m}+h"              = "focus left";
            "${m}+j"              = "focus down";
            "${m}+k"              = "focus up";
            "${m}+l"              = "focus right";

            # Focus — arrows
            "${m}+Left"           = "focus left";
            "${m}+Down"           = "focus down";
            "${m}+Up"             = "focus up";
            "${m}+Right"          = "focus right";

            # Move — vim
            "${m}+Shift+h"        = "move left";
            "${m}+Shift+j"        = "move down";
            "${m}+Shift+k"        = "move up";
            "${m}+Shift+l"        = "move right";

            # Move — arrows
            "${m}+Shift+Left"     = "move left";
            "${m}+Shift+Down"     = "move down";
            "${m}+Shift+Up"       = "move up";
            "${m}+Shift+Right"    = "move right";

            # Workspaces
            "${m}+1"              = "workspace number 1";
            "${m}+2"              = "workspace number 2";
            "${m}+3"              = "workspace number 3";
            "${m}+4"              = "workspace number 4";
            "${m}+5"              = "workspace number 5";
            "${m}+6"              = "workspace number 6";
            "${m}+7"              = "workspace number 7";
            "${m}+8"              = "workspace number 8";
            "${m}+9"              = "workspace number 9";
            "${m}+0"              = "workspace number 10";

            # Move to workspace
            "${m}+Shift+1"        = "move container to workspace number 1";
            "${m}+Shift+2"        = "move container to workspace number 2";
            "${m}+Shift+3"        = "move container to workspace number 3";
            "${m}+Shift+4"        = "move container to workspace number 4";
            "${m}+Shift+5"        = "move container to workspace number 5";
            "${m}+Shift+6"        = "move container to workspace number 6";
            "${m}+Shift+7"        = "move container to workspace number 7";
            "${m}+Shift+8"        = "move container to workspace number 8";
            "${m}+Shift+9"        = "move container to workspace number 9";
            "${m}+Shift+0"        = "move container to workspace number 10";

            # Scratchpad
            "${m}+s"              = "scratchpad show";
            "${m}+Shift+s"        = "move scratchpad";

            # Resize mode
            "${m}+r"              = "mode resize";

            # System
            "${m}+l"              = "exec swaylock -f";
            "${m}+Shift+e"        = "exec wlogout -p layer-shell";

            # Screenshot
            "Print"               = "exec grim -g \"$(slurp)\" - | wl-copy";
            "Shift+Print"         = "exec grim - | wl-copy";
            "${m}+Print"          = "exec grim -g \"$(slurp)\" ~/Pictures/Screenshots/$(date +%Y%m%d-%H%M%S).png";

            # Media
            "XF86AudioRaiseVolume"  = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
            "XF86AudioLowerVolume"  = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
            "XF86AudioMute"         = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
            "XF86AudioMicMute"      = "exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
            "XF86AudioPlay"         = "exec playerctl play-pause";
            "XF86AudioNext"         = "exec playerctl next";
            "XF86AudioPrev"         = "exec playerctl previous";

            # Brightness
            "XF86MonBrightnessUp"   = "exec brightnessctl set 5%+";
            "XF86MonBrightnessDown" = "exec brightnessctl set 5%-";

            # Clipboard
            "${m}+c"              = "exec cliphist list | fuzzel --dmenu | cliphist decode | wl-copy";
          };

        # ── Floating rules ────────────────────────────────────────────────────
        floating.criteria = [
          { app_id = "pavucontrol"; }
          { app_id = "nm-connection-editor"; }
          { app_id = "blueman-manager"; }
          { title  = "Picture-in-Picture"; }
        ];

        # ── Workspace assignments ─────────────────────────────────────────────
        assigns = {
          "1" = [{ app_id = "firefox"; }];
          "2" = [{ app_id = "code"; }];
          "3" = [{ app_id = "kitty"; }];
          "4" = [{ app_id = "discord"; }];
          "5" = [{ class = "Spotify"; }];
        };

        # ── Bar ────────────────────────────────────────────────────────────────
        bars = [{
          command    = "waybar";
          statusCommand = null;
        }];

        # ── Startup ───────────────────────────────────────────────────────────
        startup = [
          { command = "/run/current-system/sw/libexec/polkit-gnome-authentication-agent-1"; }
          { command = "wl-paste --type text --watch cliphist store"; }
          { command = "wl-paste --type image --watch cliphist store"; }
          { command = "sleep 0.5 && copyq --start-server &"; }
          { command = "sleep 1 && nm-applet --indicator &"; }
          { command = "sleep 1.5 && syncthingtray &"; }
          {
            command = ''swayidle -w \
              timeout 300 'swaylock -f' \
              timeout 600 'swaymsg "output * dpms off"' \
              resume 'swaymsg "output * dpms on"' \
              before-sleep 'swaylock -f' '';
          }
          { command = "gammastep"; }
        ];

        # ── Extra / gaming ────────────────────────────────────────────────────
        window.commands = [
          { criteria = { class  = "steam_app_.*"; }; command = "inhibit_idle fullscreen"; }
          { criteria = { class  = "cs2"; };          command = "inhibit_idle fullscreen"; }
          { criteria = { class  = "dota2"; };        command = "inhibit_idle fullscreen"; }
          { criteria = { class  = "Minecraft.*"; };  command = "inhibit_idle fullscreen"; }
        ];
      };

      extraConfig = ''
        max_render_time 1
        include /etc/sway/config.d/*
      '';
    };
  };
}
