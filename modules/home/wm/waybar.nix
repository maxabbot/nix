# modules/home/wm/waybar.nix — Waybar status bar, Gruvbox Material Dark.
#
# Two bar definitions: "main" for landscape outputs and a trimmed "portrait"
# bar for vertical monitors (derived from the per-host monitor strings —
# entries with transform 1/3). Hosts without portrait monitors get exactly
# one bar with no output filter.
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

  # Quickshell panel toggles. Targets map to Settings tabs inside Shell.qml
  # (e.g. "toggle settings audio" deep-links to the Audio tab). Invoked via
  # bash so it works even if the deployed script loses its exec bit.
  qs = "bash ~/.config/hypr/scripts/qs_manager.sh";

  # ── Portrait outputs ────────────────────────────────────────────────────────
  # Monitor strings look like "DP-2,3840x2160@60,1920x0,1.5,transform,1";
  # transform 1/3 = 90°/270° rotation → portrait.
  monitorStrings = lib.filter (m: m != null) [
    cfg.monitors.primary
    cfg.monitors.secondary
    cfg.monitors.tertiary
  ];
  isPortrait =
    s:
    let
      parts = lib.splitString "," s;
    in
    builtins.length parts >= 6
    && builtins.elemAt parts 4 == "transform"
    && lib.elem (builtins.elemAt parts 5) [
      "1"
      "3"
    ];
  portraitOutputs = map (s: lib.head (lib.splitString "," s)) (lib.filter isPortrait monitorStrings);
  hasPortrait = portraitOutputs != [ ];

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

  # Bell + unread count. Quickshell's Shell.qml writes the count file and pokes
  # the module with RTMIN+8 on every change (event-driven — no polling).
  notif-script = pkgs.writeShellScript "waybar-notifs" ''
    set -euo pipefail
    f="''${XDG_RUNTIME_DIR:-/tmp}/quickshell/notif-count"
    n=0
    [ -r "$f" ] && n=$(cat "$f")
    if [ "$n" -gt 0 ] 2>/dev/null; then
      printf '{"text":"󰂚 %s","class":"has-notifs"}\n' "$n"
    else
      printf '{"text":"󰂚","class":""}\n'
    fi
  '';

  # Non-empty while `nh os/home switch` runs from the Nix tab (same signal
  # mechanism as the notification bell; hidden via hide-empty-text).
  rebuild-script = pkgs.writeShellScript "waybar-rebuild" ''
    set -euo pipefail
    f="''${XDG_RUNTIME_DIR:-/tmp}/quickshell/rebuild"
    if [ -s "$f" ]; then echo "󱄅 building"; else echo ""; fi
  '';

  # ── Module definitions shared by both bars ──────────────────────────────────
  commonModules = {
    "hyprland/workspaces" = {
      format = "{name}";
      on-click = "activate";
      # This Hyprland evaluates dispatch requests as Lua — classic
      # "workspace e+1" syntax fails silently (see hyprland.lua binds).
      on-scroll-up = "hyprctl dispatch \"hl.dsp.focus({ workspace = 'e+1' })\"";
      on-scroll-down = "hyprctl dispatch \"hl.dsp.focus({ workspace = 'e-1' })\"";
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
        activated = "󰅶"; # filled coffee cup — staying awake
        deactivated = "󰛊"; # outline coffee cup — idle allowed
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
      on-click = "${qs} toggle settings control";
      on-click-right = "blueman-manager";
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
      on-click = "${qs} toggle settings sysinfo";
      on-click-right = "kitty -e btop";
    };

    "custom/sysinfo" = {
      exec = "${sysinfo-script}";
      interval = 2;
      tooltip = false;
      on-click = "${qs} toggle settings sysinfo";
      on-click-right = "kitty -e btop";
    };

    "custom/gpu" = {
      exec = "${gpu-script}";
      interval = 2;
      tooltip = false;
      on-click = "${qs} toggle settings sysinfo";
      on-click-right = "kitty -e btop";
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
      on-click = "${qs} toggle settings control";
      on-click-right = "nm-connection-editor";
    };

    pulseaudio = {
      scroll-step = 5;
      format = "VOL {volume}%";
      format-bluetooth = "BT {volume}%";
      format-bluetooth-muted = "BT muted";
      format-muted = "muted";
      on-click = "${qs} toggle settings audio";
      on-click-right = "pavucontrol";
    };

    "pulseaudio#source" = {
      format = "{format_source}";
      format-source = "MIC {volume}%";
      format-source-muted = "MIC muted";
      on-click = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
      on-click-right = "${qs} toggle settings audio";
      scroll-step = 5;
    };

    mpris = {
      format = "{status_icon} {dynamic}";
      dynamic-order = [
        "title"
        "artist"
      ];
      dynamic-len = 40;
      status-icons = {
        playing = "";
        paused = "";
        stopped = "";
      };
      tooltip-format = "{player}: {dynamic}";
    };

    "custom/notifications" = {
      exec = "${notif-script}";
      return-type = "json";
      interval = "once";
      signal = 8;
      tooltip = false;
      on-click = "${qs} toggle notifications";
    };

    "custom/rebuild" = {
      exec = "${rebuild-script}";
      interval = "once";
      signal = 8;
      hide-empty-text = true;
      tooltip = false;
      on-click = "${qs} toggle settings nix";
    };

    "custom/keybinds" = {
      format = "󰌌";
      tooltip-format = "Keybind cheat sheet";
      on-click = "${qs} toggle keybinds";
    };

    "custom/settings" = {
      format = "";
      tooltip-format = "Settings";
      on-click = "${qs} toggle settings";
    };
  };

  mainBar =
    {
      name = "main";
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
        "mpris"
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
      ++ lib.optional (machineType == "laptop") "battery"
      ++ [
        "custom/rebuild"
        "custom/keybinds"
        "custom/notifications"
        "custom/settings"
      ];
    }
    # Everywhere except the portrait outputs. The trailing "*" matters:
    # waybar's output arrays need a positive match — negations alone
    # match nothing. Omitted entirely on hosts without portrait monitors.
    // lib.optionalAttrs hasPortrait { output = map (n: "!" + n) portraitOutputs ++ [ "*" ]; }
    // commonModules;

  # Trimmed bar for portrait outputs (~1440 logical px on DP-2): drops the
  # window title, tray, mpris, idle inhibitor, bluetooth, mic, disk and
  # sysinfo/GPU readouts. Tray stays main-bar-only (multi-instance SNI quirks).
  slimBar = {
    name = "portrait";
    layer = "top";
    position = "top";
    height = 34;
    spacing = 4;
    output = portraitOutputs;

    "modules-left" = [ "hyprland/workspaces" ];
    "modules-center" = [ "clock" ];
    "modules-right" = [
      "pulseaudio"
      "network"
      "custom/rebuild"
      "custom/notifications"
      "custom/settings"
    ];
  }
  // commonModules;
in
{
  config = lib.mkIf (cfg.compositor == "hyprland") {
    programs.waybar = {
      enable = true;
      # From the unstable overlay — the stable 26.05 waybar duplicates a bar on
      # one output during Hyprland startup; the newer build doesn't.
      # Patched: workspace clicks dispatch via Hyprland's Lua syntax
      # (hl.dsp.focus); the stock classic "dispatch workspace N" is rejected
      # by the Lua config parser, making clicks silent no-ops.
      package = pkgs.unstable.waybar.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ../../../pkgs/waybar/hyprland-lua-dispatch.patch
        ];
      });
      systemd.enable = true;
      systemd.targets = [ "graphical-session.target" ];

      settings = [ mainBar ] ++ lib.optional hasPortrait slimBar;

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
        #custom-notifications,
        #custom-rebuild,
        #custom-keybinds,
        #custom-settings,
        #mpris,
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
        #mpris {
          color: #89b482;
        }
        #custom-notifications {
          color: #d4be98;
        }
        #custom-notifications.has-notifs {
          color: #ea6962;
        }
        #custom-keybinds {
          color: #d4be98;
        }
        #custom-settings {
          color: #d4be98;
        }
        #custom-rebuild {
          color: #d8a657;
          animation: pulse 1.2s ease-in-out infinite;
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

        @keyframes pulse {
          50% {
            color: #504945;
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
