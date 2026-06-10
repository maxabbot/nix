# modules/home/wm/waybar.nix — Waybar status bar, Gruvbox Material Dark.
{
  lib,
  config,
  pkgs,
  osConfig,
  machineType,
  ...
}:
let
  cfg = config.custom.hm;
  winModule = "hyprland/window";

  sysinfo-script = pkgs.writeShellScript "waybar-sysinfo" ''
    set -euo pipefail
    read -r a1 t1 < <(awk '/^cpu /{print $2+$4, $2+$3+$4+$5+$6+$7+$8}' /proc/stat)
    sleep 0.5
    read -r a2 t2 < <(awk '/^cpu /{print $2+$4, $2+$3+$4+$5+$6+$7+$8}' /proc/stat)
    cpu=$(( (a2-a1)*100/(t2-t1) ))
    mem=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf "%d",100*(t-a)/t}' /proc/meminfo)
    # Find the CPU package thermal zone by type rather than a fixed index,
    # which drifts between kernels/hardware.
    temp_raw=0
    for z in /sys/class/thermal/thermal_zone*; do
      case "$(cat "$z/type" 2>/dev/null)" in
        x86_pkg_temp|k10temp|coretemp) temp_raw=$(cat "$z/temp" 2>/dev/null || echo 0); break ;;
      esac
    done
    temp=$(( temp_raw / 1000 ))
    echo "CPU ''${cpu}% MEM ''${mem}% ''${temp}°C"
  '';

  gpu-script = pkgs.writeShellScript "waybar-gpu" ''
    set -euo pipefail
    usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo "?")
    temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null || echo "?")
    echo "GPU ''${usage}% ''${temp}°C"
  '';
in
{
  config = lib.mkIf (cfg.compositor == "hyprland") {
    programs.waybar = {
      enable = true;
      # From the unstable overlay — the stable 26.05 waybar duplicates a bar on
      # one output during Hyprland startup; the newer build doesn't.
      package = pkgs.unstable.waybar;
      systemd.enable = true;
      systemd.targets = [ "graphical-session.target" ];

      settings = [
        {
          layer = "top";
          position = "top";
          height = 34;
          spacing = 4;

          "modules-left" = [
            "hyprland/workspaces"
            winModule
          ];
          "modules-center" = [ "clock" ];
          "modules-right" = [
            "tray"
            "idle_inhibitor"
            "bluetooth"
            "pulseaudio"
            "pulseaudio#source"
            "network"
            "disk"
            "custom/sysinfo"
          ]
          # Gate on the nvidia flag, not machineType — the VM is machineType
          # "desktop" but has no GPU, so nvidia-smi would show "GPU ?% ?°C".
          ++ lib.optional cfg.nvidia "custom/gpu"
          ++ lib.optional (machineType == "laptop") "battery";

          "hyprland/workspaces" = {
            format = "{name}";
            on-click = "activate";
            on-scroll-up = "hyprctl dispatch workspace e+1";
            on-scroll-down = "hyprctl dispatch workspace e-1";
            persistent-workspaces = {
              "*" = 5;
            };
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
            tooltip-format-activated = "Idle inhibited (awake)";
            tooltip-format-deactivated = "Idle allowed";
          };

          bluetooth = {
            format = "BT";
            format-disabled = "";
            format-off = "";
            format-connected = "BT {device_alias}";
            tooltip-format = "{controller_alias}\t{controller_address}\n\n{num_connections} connected";
            tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{num_connections} connected\n\n{device_enumerate}";
            tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
            on-click = "blueman-manager";
          };

          clock = {
            timezone = osConfig.time.timeZone;
            format = "{:%H:%M  %b %d}";
            tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
            format-alt = "{:%Y-%m-%d}";
          };

          disk = {
            interval = 30;
            format = "DISK {percentage_used}%";
            path = "/";
            tooltip-format = "{used} / {total}";
            on-click = "kitty -e btop";
          };

          "custom/sysinfo" = {
            exec = "${sysinfo-script}";
            interval = 2;
            tooltip = false;
            on-click = "kitty -e btop";
          };

          "custom/gpu" = {
            exec = "${gpu-script}";
            interval = 2;
            tooltip = false;
            on-click = "kitty -e btop";
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
            format-wifi = "WiFi: {essid} ({signalStrength}%)";
            format-ethernet = "ETH: {ipaddr}/{cidr}";
            tooltip-format = "{ifname} via {gwaddr}";
            format-linked = "{ifname} (No IP)";
            format-disconnected = "Disconnected";
            format-alt = "{ifname}: {ipaddr}/{cidr}";
            on-click-right = "nm-connection-editor";
          };

          pulseaudio = {
            scroll-step = 5;
            format = "VOL {volume}%";
            format-bluetooth = "BT {volume}%";
            format-bluetooth-muted = "BT muted";
            format-muted = "muted";
            on-click = "pavucontrol";
          };

          "pulseaudio#source" = {
            format = "{format_source}";
            format-source = "MIC {volume}%";
            format-source-muted = "MIC muted";
            on-click = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
            on-click-right = "pavucontrol -t 4";
            scroll-step = 5;
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

        #window {
          padding: 0 10px;
          color: #d4be98;
          font-weight: bold;
        }

        #clock,
        #battery,
        #custom-sysinfo,
        #custom-gpu,
        #disk,
        #network,
        #pulseaudio,
        #bluetooth,
        #tray,
        #idle_inhibitor {
          padding: 0 10px;
          margin: 5px 0px;
          background: #3c3836;
          border-radius: 8px;
        }

        #workspaces {
          margin: 5px 0px;
          background: #3c3836;
          border-radius: 8px;
        }
        #workspaces button {
          padding: 0 8px;
          color: #7c6f64;
          background: transparent;
          border-radius: 8px;
        }
        #workspaces button.active {
          color: #282828;
          background: #d8a657;
        }
        #workspaces button.urgent {
          color: #282828;
          background: #ea6962;
        }
        #workspaces button:hover {
          color: #d4be98;
          background: #504945;
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
        #custom-sysinfo {
          color: #d3869b;
        }
        #custom-gpu {
          color: #e78a4e;
        }
        #disk {
          color: #7daea3;
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
        #pulseaudio.source {
          color: #83a598;
        }
        #pulseaudio.source.source-muted {
          color: #7c6f64;
        }
        #bluetooth {
          color: #7daea3;
        }
        #bluetooth.disabled,
        #bluetooth.off {
          color: #7c6f64;
        }
        #bluetooth.connected {
          color: #89b482;
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
