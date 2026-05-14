# modules/home/wm/waybar.nix — Waybar status bar, Gruvbox Material Dark.
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.custom.hm;
  wsModule = "hyprland/workspaces";
  winModule = "hyprland/window";
in
{
  config = lib.mkIf (cfg.compositor == "hyprland") {
    programs.waybar = {
      enable = true;
      package = pkgs.waybar;
      systemd.enable = true;
      systemd.target = "hyprland-session.target";

      settings = [
        {
          layer = "top";
          position = "top";
          height = 34;
          spacing = 4;

          "modules-left" = [
            wsModule
            winModule
          ];
          "modules-center" = [ "clock" ];
          "modules-right" = [
            "tray"
            "idle_inhibitor"
            "pulseaudio"
            "network"
            "cpu"
            "memory"
            "temperature"
            "battery"
          ];

          "${wsModule}" = {
            disable-scroll = false;
            all-outputs = true;
            format = "{icon}";
            format-icons = {
              "1" = "";
              "2" = "";
              "3" = "";
              "4" = "";
              "5" = "";
              urgent = "";
              active = "";
              default = "";
            };
            persistent_workspaces."*" = 5;
          };

          "${winModule}" = {
            format = "{}";
            max-length = 50;
            separate-outputs = true;
          };

          tray = {
            icon-size = 18;
            spacing = 10;
          };

          idle_inhibitor = {
            format = "{icon}";
            format-icons = {
              activated = "";
              deactivated = "";
            };
          };

          clock = {
            timezone = "Pacific/Auckland";
            format = "{:%H:%M  %b %d}";
            tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
            format-alt = "{:%Y-%m-%d}";
          };

          cpu = {
            interval = 2;
            format = " {usage}%";
            tooltip = true;
            on-click = "kitty -e btop";
          };

          memory = {
            interval = 5;
            format = " {}%";
            tooltip-format = "Memory: {used:0.1f}G / {total:0.1f}G";
            on-click = "kitty -e btop";
          };

          temperature = {
            thermal-zone = 2;
            critical-threshold = 80;
            format = "{icon} {temperatureC}°C";
            format-icons = [
              ""
              ""
              ""
            ];
          };

          battery = {
            states = {
              good = 95;
              warning = 30;
              critical = 15;
            };
            format = "{icon} {capacity}%";
            format-charging = " {capacity}%";
            format-plugged = " {capacity}%";
            format-alt = "{icon} {time}";
            format-icons = [
              ""
              ""
              ""
              ""
              ""
            ];
          };

          network = {
            format-wifi = " {essid} ({signalStrength}%)";
            format-ethernet = " {ipaddr}/{cidr}";
            tooltip-format = " {ifname} via {gwaddr}";
            format-linked = " {ifname} (No IP)";
            format-disconnected = "⚠ Disconnected";
            format-alt = "{ifname}: {ipaddr}/{cidr}";
            on-click-right = "nm-connection-editor";
          };

          pulseaudio = {
            scroll-step = 5;
            format = "{icon} {volume}%";
            format-bluetooth = "{icon} {volume}%";
            format-bluetooth-muted = " {icon}";
            format-muted = "";
            format-icons = {
              headphone = "";
              hands-free = "";
              headset = "";
              phone = "";
              portable = "";
              car = "";
              default = [
                ""
                ""
                ""
              ];
            };
            on-click = "pavucontrol";
          };
        }
      ];

      style = ''
        * {
          border: none;
          border-radius: 0;
          font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free", sans-serif;
          font-size: 14px;
          min-height: 0;
        }

        window#waybar {
          background: rgba(40, 40, 40, 0.9);
          color: #d4be98;
        }

        #workspaces {
          background: transparent;
          margin: 5px;
          padding: 0px 5px;
        }

        #workspaces button {
          padding: 0px 10px;
          background: transparent;
          color: #7c6f64;
          border-bottom: 3px solid transparent;
        }

        #workspaces button.focused,
        #workspaces button.active {
          color: #7daea3;
          border-bottom: 3px solid #7daea3;
        }

        #workspaces button.urgent {
          color: #ea6962;
          border-bottom: 3px solid #ea6962;
        }

        #workspaces button:hover {
          background: rgba(60, 56, 54, 0.5);
          color: #d4be98;
        }

        #window {
          padding: 0 10px;
          color: #d4be98;
          font-weight: bold;
        }

        #clock,
        #battery,
        #cpu,
        #memory,
        #temperature,
        #network,
        #pulseaudio,
        #tray,
        #idle_inhibitor {
          padding: 0 10px;
          margin: 5px 0px;
          background: #3c3836;
          border-radius: 8px;
        }

        #clock {
          color: #d8a657;
          font-weight: bold;
        }
        #battery {
          color: #a9b665;
        }
        #battery.charging {
          color: #a9b665;
        }
        #battery.warning:not(.charging) {
          color: #d8a657;
        }
        #battery.critical:not(.charging) {
          color: #ea6962;
          animation: blink 1s linear infinite;
        }
        #cpu {
          color: #d3869b;
        }
        #memory {
          color: #7daea3;
        }
        #temperature {
          color: #e78a4e;
        }
        #temperature.critical {
          color: #ea6962;
          animation: blink 1s linear infinite;
        }
        #network {
          color: #89b482;
        }
        #network.disconnected {
          color: #ea6962;
        }
        #pulseaudio {
          color: #d8a657;
        }
        #pulseaudio.muted {
          color: #7c6f64;
        }
        #tray {
          background: transparent;
        }
        #tray > .passive {
          -gtk-icon-effect: dim;
        }
        #tray > .needs-attention {
          -gtk-icon-effect: highlight;
        }
        #idle_inhibitor {
          color: #d4be98;
        }
        #idle_inhibitor.activated {
          color: #a9b665;
        }

        @keyframes blink {
          to {
            color: #282828;
          }
        }

        tooltip {
          background: #282828;
          border: 1px solid #7daea3;
          border-radius: 8px;
        }
        tooltip label {
          color: #d4be98;
        }
      '';
    };
  };
}
