# Waybar

Status bar for the Hyprland hosts, themed Gruvbox Material Dark. Defined entirely in `modules/home/wm/waybar.nix` (Home Manager `programs.waybar`). Loaded only when `custom.hm.compositor == "hyprland"`, so the `minimal` host stays bar-free. Waybar is the **only** bar — Quickshell (`QUICKSHELL.md`) provides the panels/overlays its modules open, not a bar of its own.

## Build notes

- **Package** — pinned to `pkgs.unstable.waybar`, patched (`pkgs/waybar/hyprland-lua-dispatch.patch`) so workspace clicks dispatch via Hyprland's Lua syntax (`hl.dsp.focus`); the stock classic dispatch strings are silently rejected by the Lua config parser. The stable 26.05 build also duplicates a bar on one output during Hyprland startup.
- **Service** — `systemd.enable = true`, bound to `graphical-session.target`, with a 2s `ExecStartPre` hold so Hyprland's outputs settle before the bar attaches modules.
- **Quickshell bridge** — `custom/notifications` and `custom/rebuild` are event-driven: Shell.qml writes `$XDG_RUNTIME_DIR/quickshell/{notif-count,rebuild}` and signals `RTMIN+8`; both modules use `"interval": "once"` + `"signal": 8`.

## Two bars

| Bar | Outputs | Layout |
|---|---|---|
| `main` | every landscape output (`!<portrait>` + `*`; no filter on hosts without portrait monitors) | full module set below |
| `portrait` | outputs whose monitor string carries `transform` 1/3 (e.g. DP-2 on home-desktop) | workspaces · clock · pulseaudio, network, rebuild, notifications, settings |

Portrait outputs are derived in Nix from the per-host `custom.hm.monitors` strings — no extra host plumbing.

## Main bar layout

| Region | Modules |
|---|---|
| Left | `hyprland/workspaces`, `custom/scratchpad`, `hyprland/window` |
| Center | `clock`, `custom/weather` |
| Right | `mpris`, **system group** (`cpu`, `memory`, `custom/temp`, `custom/gpu` on NVIDIA hosts), `custom/disk`, **connectivity group** (`custom/recording`, `custom/camera`, `custom/mic`, `pulseaudio`, `bluetooth`, `network`), `battery` (laptops), `idle_inhibitor`, `tray`, `custom/rebuild`, `custom/keybinds`, `custom/notifications`, `custom/settings` |

## Modules

Most clicks deep-link into the Quickshell Settings panel via `qs_manager.sh toggle settings <tab>`; right-clicks open the traditional GUI tool.

- **`hyprland/workspaces`** — 5 persistent buttons; click to activate, scroll to cycle (Lua dispatch).
- **`custom/scratchpad`** — hidden while the special workspaces are empty; orange count of stashed windows. Click toggles `special:magic`. Signal-driven (RTMIN+9) from `hyprland.lua`'s window open/close/move handlers.
- **`clock`** — `HH:MM`, click toggles to date; calendar tooltip; timezone follows `osConfig.time.timeZone`.
- **`custom/weather`** — wttr.in (IP-located, no key), 30-min disk cache, condition glyph; hidden offline.
- **`cpu` / `memory` / `custom/temp` / `custom/gpu`** — 2s stats with warning/critical colour states; temp matches the thermal zone by type (`x86_pkg_temp`/`k10temp`/`coretemp`), GPU only on `nvidia` hosts. Click → System tab, right-click → btop.
- **`custom/disk`** — hidden below 85% root usage; amber ≥85, red ≥95.
- **`custom/camera`** — red glyph while any process holds `/dev/video*` (via `fuser`); hidden otherwise.
- **`custom/mic`** — hidden while idle+unmuted; red when muted, green while a real capture stream (≥8kHz) records. Click toggles mute.
- **`custom/recording`** — hidden while idle, red while the screen is captured: pgrep on recorder process names (wf-recorder, wl-screenrec, gpu-screen-recorder) plus PipeWire `Stream/*/Video` nodes for portal shares. Signal-driven (RTMIN+10) from `hyprland.lua`'s `screenshare.state` handler, with a slow fallback poll for KMS-mode gpu-screen-recorder.
- **`pulseaudio`** — volume; scroll adjusts, click → Audio tab, right-click → pavucontrol.
- **`bluetooth` / `network`** — click → Control tab, right-click → blueman / nm-connection-editor.
- **`mpris`** — `{status_icon} title – artist` (40 chars); standalone capsule so it disappears cleanly with no player.
- **`battery`** *(laptops)* — icon + capacity; blinks red below 15% when discharging.
- **`idle_inhibitor`** — coffee-cup toggle.
- **`custom/rebuild`** — pulsing `󱄅 building` while the Nix tab runs `nh os/home switch`; hidden otherwise.
- **`custom/notifications`** — bell + unread count (red when non-zero); click opens the notification centre.
- **`custom/keybinds` / `custom/settings`** — open the cheat sheet / Settings panel.

## Styling

Inline CSS in the `style` block. Palette values are interpolated from `config/stylix/palette.nix` (Stylix's waybar target stays disabled). Conventions:

- Bar: transparent window background (the capsules carry the fill), 36px tall, 4px module spacing.
- Capsules: groups (`#system`, `#connectivity`) and standalone modules share a rounded `#3c3836` pill; group children are transparent inside it. `tray` is transparent.
- Per-module accent colors set foreground only (clock teal, weather amber, mpris green, camera red-when-active, etc.).
- `battery.critical` blinks; `custom/rebuild` pulses (`@keyframes`).
- Tooltips: dark `#282828` with a teal border.

## Changing things

| Want to… | Where |
|---|---|
| Add/remove a module | `commonModules` + the `modules-left/center/right` arrays (both bars share `commonModules`) |
| Restyle a module | the `style = ''…''` CSS block (match the existing pill + accent pattern) |
| Change colors globally | edit `config/stylix/palette.nix` (the style block interpolates it) |
| Adjust the portrait bar | the `slimBar` definition / `isPortrait` derivation |

After edits: `nixup` (or `nixos-rebuild dry-build --flake /etc/nixos#<host>` to validate without switching).
