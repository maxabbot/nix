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
  palette = import ../../../config/stylix/palette.nix;
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

  # CPU temperature as JSON so the capsule can carry a threshold class
  # (warning ≥70, critical ≥80). Shows the *average* of the per-core coretemp
  # sensors — the package sensor is the peak core and jumps around on
  # single-core bursts (same reasoning as fan2go.nix). Falls back to the
  # package/thermal-zone reading on hosts without per-core sensors (VM).
  temp-script = pkgs.writeShellScript "waybar-temp" ''
    set -euo pipefail
    total=0 n=0 pkg=0
    for f in /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp*_input; do
      if [ "''${f##*/}" = "temp1_input" ]; then
        pkg=$(cat "$f" 2>/dev/null || echo 0)
        continue
      fi
      t=$(cat "$f" 2>/dev/null || echo "")
      [ -n "$t" ] || continue
      total=$((total + t)) n=$((n + 1))
    done
    if [ "$n" -gt 0 ]; then
      temp_raw=$((total / n))
    else
      temp_raw=0
      for z in /sys/class/thermal/thermal_zone*; do
        case "$(cat "$z/type" 2>/dev/null)" in
          x86_pkg_temp|k10temp|coretemp) temp_raw=$(cat "$z/temp" 2>/dev/null || echo 0); break ;;
        esac
      done
    fi
    t=$(( temp_raw / 1000 ))
    cls=""
    if   [ "$t" -ge 80 ]; then cls="critical"
    elif [ "$t" -ge 70 ]; then cls="warning"
    fi
    tip="CPU core avg ''${t}°C"
    [ "$pkg" -gt 0 ] && tip="$tip · package $((pkg / 1000))°C"
    printf '{"text":"󰔏 %s°","class":"%s","tooltip":"%s"}\n' "$t" "$cls" "$tip"
  '';

  # GPU utilisation + temperature. Class is the worse of the two thresholds:
  # usage ≥70/≥90, temp ≥75/≥85 (RTX 40-series throttles around 83–84°C).
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
    if [ "$temp" != "?" ] && [ "$cls" != "critical" ]; then
      if   [ "$temp" -ge 85 ]; then cls="critical"
      elif [ "$temp" -ge 75 ]; then cls="warning"
      fi
    fi
    printf '{"text":"󰢮 %s 󰔏 %s°","class":"%s","tooltip":"GPU %s%% · %s°C"}\n' "$usage" "$temp" "$cls" "$usage" "$temp"
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

  # Camera indicator: hidden while idle, red glyph when any process holds a
  # /dev/video* handle (browser/Zoom/OBS capturing). fuser is referenced by
  # store path so it works regardless of the session PATH. The glob stays
  # literal (→ fuser errors → hidden) on machines with no camera node.
  camera-script = pkgs.writeShellScript "waybar-camera" ''
    set -euo pipefail
    if ${pkgs.psmisc}/bin/fuser /dev/video* >/dev/null 2>&1; then
      printf '{"text":"󰄀","class":"active","tooltip":"Camera in use"}\n'
    else
      printf '\n'
    fi
  '';

  # Screen recording / sharing indicator: hidden while idle, red glyph when the
  # screen is being captured. Two signals cover the two capture paths:
  #   • wlr-screencopy recorders (wf-recorder, wl-screenrec, gpu-screen-recorder)
  #     grab frames directly and never touch PipeWire — caught by process name.
  #   • Portal screen-shares (browser, Zoom, Discord, OBS, Kooha) route through
  #     xdg-desktop-portal, which publishes a PipeWire *video stream* node —
  #     caught by pw-dump. Webcams are "Video/Source" *devices*, not "Stream/…"
  #     nodes, so they never match here (the camera module owns those).
  recording-script = pkgs.writeShellScript "waybar-recording" ''
    set -euo pipefail
    active=""
    # Match the process *name* (comm), not -f/cmdline: -f would false-match any
    # shell whose arguments happen to contain these strings. comm is truncated
    # to 15 chars by the kernel, so "gpu-screen-recorder" is matched by its
    # "gpu-screen-rec" prefix.
    if ${pkgs.procps}/bin/pgrep 'wf-recorder|wl-screenrec|gpu-screen-rec' >/dev/null 2>&1; then
      active=1
    elif ${pkgs.pipewire}/bin/pw-dump 2>/dev/null \
        | grep -qE '"media\.class":[[:space:]]*"Stream/[^"]*Video"'; then
      active=1
    fi
    if [ -n "$active" ]; then
      printf '{"text":"󰑊","class":"active","tooltip":"Screen recording / sharing active"}\n'
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

  # Scratchpad badge: hidden while the special workspaces are empty, orange
  # count while windows are stashed there. jq builds the whole JSON blob so
  # window classes can't break the quoting.
  scratchpad-script = pkgs.writeShellScript "waybar-scratchpad" ''
    set -euo pipefail
    { hyprctl clients -j 2>/dev/null || echo '[]'; } | ${pkgs.jq}/bin/jq -c '
      [.[] | select(.mapped and (.workspace.name | startswith("special:")))]
      | select(length > 0)
      | { text: "󰖲 \(length)",
          tooltip: ("Scratchpad: " + ([.[].class] | join(", "))) }'
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

  # Current weather beside the clock. wttr.in is IP-located (no API key) and
  # cached on disk for 30 min so repeated waybar restarts don't hammer it;
  # condition text maps to a Nerd Font glyph. Hides (empty JSON) when offline.
  weather-script = pkgs.writeShellScript "waybar-weather" ''
    set -euo pipefail
    d="''${XDG_CACHE_HOME:-$HOME/.cache}/waybar"
    mkdir -p "$d"
    f="$d/weather"
    # Per-PID temp: one weather module runs per bar, so several fire at once on
    # a multi-output setup — a shared "$f.tmp" makes the first mv win and the
    # rest fail with "cannot stat". "$f.$$" gives each invocation its own file.
    if [ -z "$(find "$f" -mmin -30 2>/dev/null)" ]; then
      t="$f.$$"
      if curl -s --max-time 5 'wttr.in/?format=%t|%C' 2>/dev/null > "$t"; then
        mv "$t" "$f"
      else
        rm -f "$t"
      fi
    fi
    raw=$(cat "$f" 2>/dev/null || true)
    temp=''${raw%%|*}
    cond=''${raw#*|}
    temp=$(printf '%s' "$temp" | tr -d '+ ')
    # Bail to an empty (hidden) module unless we got a real temperature.
    case "$temp" in *[0-9]*) : ;; *) printf '\n'; exit 0 ;; esac
    lc=$(printf '%s' "$cond" | tr '[:upper:]' '[:lower:]')
    case "$lc" in
      *thunder*)                      icon="󰖓" ;;
      *snow*|*sleet*|*blizzard*|*ice*) icon="󰖘" ;;
      *rain*|*drizzle*|*shower*)      icon="󰖗" ;;
      *fog*|*mist*|*haze*)            icon="󰖑" ;;
      *overcast*)                     icon="󰖐" ;;
      *cloud*)                        icon="󰖕" ;;
      *sun*|*clear*)                  icon="󰖙" ;;
      *)                              icon="󰖕" ;;
    esac
    printf '{"text":"%s %s","tooltip":"%s","class":"weather"}\n' "$icon" "$temp" "$cond"
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

    "custom/scratchpad" = {
      exec = "${scratchpad-script}";
      return-type = "json";
      # Event-driven: hyprland.lua pokes RTMIN+9 from hl.on window
      # open/close/move handlers (same mechanism as the notification bell).
      interval = "once";
      signal = 9;
      # Lua dispatch syntax — see the workspaces scroll handlers above.
      on-click = "hyprctl dispatch \"hl.dsp.workspace.toggle_special('magic')\"";
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

    "custom/weather" = {
      exec = "${weather-script}";
      return-type = "json";
      interval = 1800;
      on-click = "${qs} toggle settings control";
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

    "custom/camera" = {
      exec = "${camera-script}";
      return-type = "json";
      interval = 2;
      tooltip = true;
    };

    "custom/recording" = {
      exec = "${recording-script}";
      return-type = "json";
      # Signal-driven from hyprland.lua's screenshare.state handler; the slow
      # interval is only a fallback for KMS-mode gpu-screen-recorder, which
      # captures behind the compositor (no event, no PipeWire stream) and is
      # only caught by the script's pgrep branch.
      interval = 15;
      signal = 10;
      tooltip = true;
    };

    battery = {
      states = {
        good = 95;
        warning = 30;
        critical = 15;
      };
      format = "{icon} {capacity}%";
      format-charging = "󰂄 {capacity}%";
      format-plugged = "󰚥 {capacity}%";
      format-alt = "{icon} {time}";
      format-icons = [
        "󰁺"
        "󰁼"
        "󰁾"
        "󰂀"
        "󰁹"
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

  mainBar = {
    name = "main";
    layer = "top";
    position = "top";
    height = 36;
    spacing = 4;

    # ── Capsule groups: related stats share one rounded background ───────────
    # (mpris is a standalone capsule, not a group, so it disappears cleanly
    # when no player is active instead of leaving an empty pill behind.)
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
        "custom/recording"
        "custom/camera"
        "custom/mic"
        "pulseaudio"
        "bluetooth"
        "network"
      ];
    };

    "modules-left" = [
      "hyprland/workspaces"
      "custom/scratchpad"
      winModule
    ];
    "modules-center" = [
      "clock"
      "custom/weather"
    ];
    "modules-right" = [
      "mpris"
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
    height = 36;
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
        /* Gruvbox Material Dark — colours interpolated from
           config/stylix/palette.nix */
        * {
          border: none;
          border-radius: 0;
          font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free", sans-serif;
          font-size: 14px;
          min-height: 0;
        }

        window#waybar {
          background: transparent;
          color: ${palette.fg};
        }

        #window {
          padding: 0 12px;
          color: ${palette.fg};
          font-weight: bold;
        }

        /* ── Capsules: groups + standalone modules share one rounded bg ──────── */
        #mpris,
        #system,
        #connectivity,
        #clock,
        #custom-weather,
        #custom-scratchpad,
        #custom-disk,
        #battery,
        #idle_inhibitor,
        #custom-notifications,
        #custom-rebuild,
        #custom-keybinds,
        #custom-settings {
          background: ${palette.bg1};
          border-radius: 8px;
          margin: 5px 0;
          padding: 0 10px;
        }

        /* Group capsules let their children supply the inner horizontal spacing
           so adjacent stats read as one unit. */
        #system,
        #connectivity {
          padding: 0 4px;
        }
        #cpu,
        #memory,
        #custom-temp,
        #custom-gpu,
        #custom-camera,
        #custom-mic,
        #pulseaudio,
        #bluetooth,
        #network {
          background: transparent;
          padding: 0 7px;
          color: ${palette.fg};
        }

        /* ── Workspace pills ─────────────────────────────────────────────────── */
        #workspaces {
          margin: 5px 0;
          background: ${palette.bg1};
          border-radius: 8px;
          padding: 0 2px;
        }
        #workspaces button {
          min-width: 18px;
          padding: 0 8px;
          margin: 3px 2px;
          color: ${palette.gray};
          background: transparent;
          border-radius: 6px;
        }
        #workspaces button.active {
          color: ${palette.bg0Hard};
          background: ${palette.blue};
        }
        #workspaces button.urgent {
          color: ${palette.bg0Hard};
          background: ${palette.red};
        }
        #workspaces button:hover {
          color: ${palette.fg};
          background: ${palette.bg2};
        }

        /* ── Threshold states (neutral cream until they matter) ──────────────── */
        #cpu.warning,
        #memory.warning,
        #custom-temp.warning,
        #custom-gpu.warning,
        #custom-disk.warning {
          color: ${palette.yellow};
        }
        #cpu.critical,
        #memory.critical,
        #custom-temp.critical,
        #custom-gpu.critical,
        #custom-disk.critical {
          color: ${palette.red};
        }
        #custom-disk {
          color: ${palette.yellow};
        }

        /* ── Per-module accents ──────────────────────────────────────────────── */
        #clock {
          color: ${palette.blue};
          font-weight: bold;
        }
        #custom-weather {
          color: ${palette.yellow};
        }
        #custom-scratchpad {
          color: ${palette.orange};
        }
        #mpris {
          color: ${palette.green};
        }
        #pulseaudio {
          color: ${palette.blue};
        }
        #pulseaudio.muted {
          color: ${palette.gray};
        }
        #custom-mic.active {
          color: ${palette.green};
        }
        #custom-mic.muted {
          color: ${palette.red};
        }
        #custom-camera.active {
          color: ${palette.red};
        }
        #custom-recording.active {
          color: ${palette.red};
        }
        #network {
          color: ${palette.aqua};
        }
        #network.disconnected {
          color: ${palette.red};
        }
        #network.linked {
          color: ${palette.yellow};
        }
        #bluetooth {
          color: ${palette.blue};
        }
        #bluetooth.connected {
          color: ${palette.aqua};
        }
        #idle_inhibitor {
          color: ${palette.fg};
        }
        #idle_inhibitor.activated {
          color: ${palette.green};
        }

        #battery {
          color: ${palette.green};
        }
        #battery.warning:not(.charging) {
          color: ${palette.yellow};
        }
        #battery.critical:not(.charging) {
          color: ${palette.red};
          animation: blink 1s linear infinite;
        }

        #custom-notifications {
          color: ${palette.fg};
        }
        #custom-notifications.has-notifs {
          color: ${palette.red};
        }
        #custom-keybinds,
        #custom-settings {
          color: ${palette.fg};
        }
        #custom-rebuild {
          color: ${palette.yellow};
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
            color: ${palette.bg0Hard};
          }
        }
        @keyframes pulse {
          50% {
            color: ${palette.bg2};
          }
        }

        tooltip {
          background: ${palette.bg0};
          border: 1px solid ${palette.blue};
          border-radius: 8px;
        }
        tooltip label {
          color: ${palette.fg};
        }
      '';
    };

    # Waybar launches on graphical-session.target, which fires while Hyprland is
    # still bringing outputs online — the bar can render before all monitors
    # exist, and modules occasionally fail to attach (the weather module dropped
    # off the main bar this way). Hold start briefly so the outputs settle first.
    systemd.user.services.waybar.Service.ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
  };
}
