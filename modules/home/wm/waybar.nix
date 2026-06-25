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

  # CPU package temperature as JSON so the capsule can carry a threshold class
  # (warning ≥70, critical ≥80). Thermal zone is matched by type rather than a
  # fixed index, which drifts between kernels/hardware.
  temp-script = pkgs.writeShellScript "waybar-temp" ''
    set -euo pipefail
    temp_raw=0
    for z in /sys/class/thermal/thermal_zone*; do
      case "$(cat "$z/type" 2>/dev/null)" in
        x86_pkg_temp|k10temp|coretemp) temp_raw=$(cat "$z/temp" 2>/dev/null || echo 0); break ;;
      esac
    done
    t=$(( temp_raw / 1000 ))
    cls=""
    if   [ "$t" -ge 80 ]; then cls="critical"
    elif [ "$t" -ge 70 ]; then cls="warning"
    fi
    printf '{"text":"󰔏 %s°","class":"%s","tooltip":"CPU package %s°C"}\n' "$t" "$cls" "$t"
  '';

  # GPU utilisation with the same threshold logic (≥70 / ≥90); GPU temperature
  # rides along in the tooltip.
  gpu-script = pkgs.writeShellScript "waybar-gpu" ''
    set -euo pipefail
    read -r usage temp < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu \
      --format=csv,noheader,nounits 2>/dev/null | tr -d ' ' | tr ',' ' ') || true
    usage=''${usage:-?}
    temp=''${temp:-?}
    cls=""
    if [ "$usage" != "?" ]; then
      if   [ "$usage" -ge 90 ]; then cls="critical"
      elif [ "$usage" -ge 70 ]; then cls="warning"
      fi
    fi
    printf '{"text":"󰢮 %s","class":"%s","tooltip":"GPU %s%% · %s°C"}\n' "$usage" "$cls" "$usage" "$temp"
  '';

  # Mic indicator that stays hidden while idle+unmuted (waybar hides a custom
  # module on empty output): red glyph when muted, green while a stream records.
  mic-script = pkgs.writeShellScript "waybar-mic" ''
    set -euo pipefail
    if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q MUTED; then
      printf '{"text":"󰍭","class":"muted","tooltip":"Microphone muted"}\n'
      exit 0
    fi
    # Real capture uses normal sample rates; UI peak/level meters run at the
    # display refresh (60–144Hz), so only count streams at >=8000Hz as in-use.
    hz_max=$(pactl list short source-outputs 2>/dev/null \
      | grep -oE '[0-9]+Hz' | tr -dc '0-9\n' | sort -n | tail -1)
    if [ "''${hz_max:-0}" -ge 8000 ]; then
      printf '{"text":"󰍬","class":"active","tooltip":"Microphone in use"}\n'
    else
      printf '\n'
    fi
  '';

  # Disk usage that only surfaces above 85% (amber), 95% (red); empty otherwise.
  disk-script = pkgs.writeShellScript "waybar-disk" ''
    set -euo pipefail
    used=$(df --output=pcent / | tail -1 | tr -dc '0-9')
    if [ "''${used:-0}" -lt 85 ]; then printf '\n'; exit 0; fi
    cls="warning"
    if [ "$used" -ge 95 ]; then cls="critical"; fi
    printf '{"text":"󰋊 %s","class":"%s","tooltip":"Disk %s%% used"}\n' "$used" "$cls" "$used"
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
      format = "󰂯";
      format-disabled = "";
      format-off = "";
      format-connected = "󰂱";
      tooltip-format = "{controller_alias}\t{controller_address}\n\n{num_connections} connected";
      tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{num_connections} connected\n\n{device_enumerate}";
      tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
      on-click = "${qs} toggle settings control";
      on-click-right = "blueman-manager";
    };

    clock = {
      timezone = osConfig.time.timeZone;
      format = "󰥔 {:%H:%M}";
      tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      format-alt = "󰃭 {:%a %d %b}";
    };

    cpu = {
      interval = 2;
      format = "󰻠 {usage}";
      states = {
        warning = 70;
        critical = 90;
      };
      on-click = "${qs} toggle settings sysinfo";
      on-click-right = "kitty -e btop";
    };

    memory = {
      interval = 2;
      format = "󰍛 {percentage}";
      states = {
        warning = 75;
        critical = 90;
      };
      on-click = "${qs} toggle settings sysinfo";
      on-click-right = "kitty -e btop";
    };

    "custom/temp" = {
      exec = "${temp-script}";
      return-type = "json";
      interval = 2;
      on-click = "${qs} toggle settings sysinfo";
      on-click-right = "kitty -e btop";
    };

    "custom/gpu" = {
      exec = "${gpu-script}";
      return-type = "json";
      interval = 2;
      on-click = "${qs} toggle settings sysinfo";
      on-click-right = "kitty -e btop";
    };

    "custom/disk" = {
      exec = "${disk-script}";
      return-type = "json";
      interval = 30;
      on-click = "${qs} toggle settings sysinfo";
      on-click-right = "kitty -e btop";
    };

    "custom/mic" = {
      exec = "${mic-script}";
      return-type = "json";
      interval = 2;
      on-click = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
      on-click-right = "${qs} toggle settings audio";
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
      format-wifi = "󰖩 {signalStrength}";
      format-ethernet = "󰈀";
      format-linked = "󰈁";
      format-disconnected = "󰖪";
      tooltip-format-wifi = "{essid} ({signalStrength}%)\n{ifname} via {gwaddr}";
      tooltip-format-ethernet = "{ifname}: {ipaddr}/{cidr}";
      tooltip-format-linked = "{ifname} (no IP)";
      tooltip-format-disconnected = "Disconnected";
      on-click = "${qs} toggle settings control";
      on-click-right = "nm-connection-editor";
    };

    pulseaudio = {
      scroll-step = 5;
      format = "{icon} {volume}";
      format-bluetooth = "󰂯 {volume}";
      format-bluetooth-muted = "󰂲";
      format-muted = "󰝟";
      format-icons = {
        default = [
          "󰕿"
          "󰖀"
          "󰕾"
        ];
        headphone = "󰋋";
        headset = "󰋎";
      };
      on-click = "${qs} toggle settings audio";
      on-click-right = "pavucontrol";
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

      # ── Capsule groups: related stats share one rounded background ───────────
      "group/media" = {
        orientation = "horizontal";
        modules = [ "mpris" ];
      };
      "group/system" = {
        orientation = "horizontal";
        # Gate the GPU on the nvidia flag, not machineType — the VM is
        # machineType "desktop" but has no GPU, so nvidia-smi would show "?".
        modules = [
          "cpu"
          "memory"
          "custom/temp"
        ]
        ++ lib.optional cfg.nvidia "custom/gpu";
      };
      "group/connectivity" = {
        orientation = "horizontal";
        modules = [
          "custom/mic"
          "pulseaudio"
          "bluetooth"
          "network"
        ];
      };

      "modules-left" = [
        "hyprland/workspaces"
        winModule
      ];
      "modules-center" = [ "clock" ];
      "modules-right" = [
        "group/media"
        "group/system"
        "custom/disk"
        "group/connectivity"
      ]
      ++ lib.optional (machineType == "laptop") "battery"
      ++ [
        "idle_inhibitor"
        "tray"
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
        /* Gruvbox Material Dark — bg0 #1d2021, bg_s #3c3836, fg #d4be98,
           gray #928374, red #ea6962, orange #e78a4e, yellow #d8a657,
           green #a9b665, aqua #89b482, blue #7daea3 */
        * {
          border: none;
          border-radius: 0;
          font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free", sans-serif;
          font-size: 14px;
          min-height: 0;
        }

        window#waybar {
          background: rgba(29, 32, 33, 0.92);
          color: #d4be98;
        }

        #window {
          padding: 0 12px;
          color: #d4be98;
          font-weight: bold;
        }

        /* ── Capsules: groups + standalone modules share one rounded bg ──────── */
        #media,
        #system,
        #connectivity,
        #clock,
        #custom-disk,
        #battery,
        #idle_inhibitor,
        #custom-notifications,
        #custom-rebuild,
        #custom-keybinds,
        #custom-settings {
          background: #3c3836;
          border-radius: 8px;
          margin: 5px 0;
          padding: 0 10px;
        }

        /* Group capsules let their children supply the inner horizontal spacing
           so adjacent stats read as one unit. */
        #media,
        #system,
        #connectivity {
          padding: 0 4px;
        }
        #cpu,
        #memory,
        #custom-temp,
        #custom-gpu,
        #custom-mic,
        #pulseaudio,
        #bluetooth,
        #network,
        #mpris {
          background: transparent;
          padding: 0 7px;
          color: #d4be98;
        }

        /* ── Workspace pills ─────────────────────────────────────────────────── */
        #workspaces {
          margin: 5px 0;
          background: #3c3836;
          border-radius: 8px;
          padding: 0 2px;
        }
        #workspaces button {
          min-width: 18px;
          padding: 0 8px;
          margin: 3px 2px;
          color: #928374;
          background: transparent;
          border-radius: 6px;
        }
        #workspaces button.active {
          color: #1d2021;
          background: #e78a4e;
        }
        #workspaces button.urgent {
          color: #1d2021;
          background: #ea6962;
        }
        #workspaces button:hover {
          color: #d4be98;
          background: #504945;
        }

        /* ── Threshold states (neutral cream until they matter) ──────────────── */
        #cpu.warning,
        #memory.warning,
        #custom-temp.warning,
        #custom-gpu.warning,
        #custom-disk.warning {
          color: #d8a657;
        }
        #cpu.critical,
        #memory.critical,
        #custom-temp.critical,
        #custom-gpu.critical,
        #custom-disk.critical {
          color: #ea6962;
        }
        #custom-disk {
          color: #d8a657;
        }

        /* ── Per-module accents ──────────────────────────────────────────────── */
        #clock {
          color: #7daea3;
          font-weight: bold;
        }
        #mpris {
          color: #a9b665;
        }
        #pulseaudio {
          color: #7daea3;
        }
        #pulseaudio.muted {
          color: #928374;
        }
        #custom-mic.active {
          color: #a9b665;
        }
        #custom-mic.muted {
          color: #ea6962;
        }
        #network {
          color: #89b482;
        }
        #network.disconnected {
          color: #ea6962;
        }
        #network.linked {
          color: #d8a657;
        }
        #bluetooth {
          color: #7daea3;
        }
        #bluetooth.connected {
          color: #89b482;
        }
        #idle_inhibitor {
          color: #d4be98;
        }
        #idle_inhibitor.activated {
          color: #a9b665;
        }

        #battery {
          color: #a9b665;
        }
        #battery.warning:not(.charging) {
          color: #d8a657;
        }
        #battery.critical:not(.charging) {
          color: #ea6962;
          animation: blink 1s linear infinite;
        }

        #custom-notifications {
          color: #d4be98;
        }
        #custom-notifications.has-notifs {
          color: #ea6962;
        }
        #custom-keybinds,
        #custom-settings {
          color: #d4be98;
        }
        #custom-rebuild {
          color: #d8a657;
          animation: pulse 1.2s ease-in-out infinite;
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

        @keyframes blink {
          to {
            color: #1d2021;
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
