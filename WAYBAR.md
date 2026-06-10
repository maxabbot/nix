# Waybar

Top status bar for the Hyprland hosts, themed Gruvbox Material Dark. Defined entirely in `modules/home/wm/waybar.nix` (Home Manager `programs.waybar`). Loaded only when `custom.hm.compositor == "hyprland"`, so the `minimal` host stays bar-free.

> Note: Quickshell (`QUICKSHELL.md`) ships a bottom bar that overlaps this one in scope. Waybar is the top bar; keep both in mind when changing either.

## Build notes

- **Package** — pinned to `pkgs.unstable.waybar`. The stable 26.05 build duplicates a bar on one output during Hyprland startup; the unstable build doesn't.
- **Service** — `systemd.enable = true`, bound to `graphical-session.target`.
- **Per-host modules** — `machineType` selects the last right-hand module: `custom/gpu` on `desktop`, `battery` on `laptop`.

## Layout

| Region | Modules |
|---|---|
| Left | `hyprland/workspaces`, `hyprland/window` |
| Center | `clock` |
| Right | `tray`, `idle_inhibitor`, `bluetooth`, `pulseaudio`, `pulseaudio#source` (mic), `network`, `disk`, `custom/sysinfo`, then `custom/gpu` (desktop) **or** `battery` (laptop) |

## Modules

**`hyprland/workspaces`** — 5 persistent workspace buttons. Click to activate, scroll to cycle (`hyprctl dispatch workspace e±1`). Active = amber fill, urgent = red, empty = dim grey, hover highlight.

**`hyprland/window`** — Focused window title, `separate-outputs`, max 50 chars, bold.

**`clock`** — `HH:MM  Mon DD`; left-click toggles to `YYYY-MM-DD` (`format-alt`). Tooltip shows a month calendar. Timezone follows `osConfig.time.timeZone`.

**`tray`** — System tray, 18px icons. Rendered transparent (no pill) so it floats over the bar background.

**`idle_inhibitor`** — Coffee-cup glyph: filled/green when inhibited (awake), empty when idle is allowed. Click toggles.

**`bluetooth`** — Shows connected device alias; tooltip enumerates connections. Click drops down the Quickshell Control Center, right-click opens `blueman-manager`. Teal idle → green connected → grey when off/disabled.

**`pulseaudio`** — Default sink: `VOL {volume}%`, `BT {volume}%` on Bluetooth, `muted` when muted. Scroll adjusts (step 5), click drops down the Quickshell Audio mixer, right-click opens `pavucontrol`.

**`pulseaudio#source`** — Microphone: `MIC {volume}%` / `MIC muted`. Click toggles mute (`wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle`), right-click drops down the Quickshell Audio mixer. Blue normally, grey when muted.

**`network`** — `WiFi: {essid} ({signal}%)` or `ETH: {ip}/{cidr}`; left-click drops down the Quickshell Control Center, right-click opens `nm-connection-editor`. Red when disconnected.

**`disk`** — Root filesystem `DISK {used}%`, tooltip `used / total`, click drops down the Quickshell SysInfo panel, right-click opens `btop` in kitty. 30s interval.

**`custom/sysinfo`** — `CPU x% MEM y% z°C` every 2s from `waybar-sysinfo` script (see below). Click drops down the Quickshell SysInfo panel, right-click opens `btop`.

**`custom/gpu`** *(desktop)* — `GPU x% z°C` from `nvidia-smi` every 2s. Click drops down the Quickshell SysInfo panel, right-click opens `btop`.

> Dropdowns: clicks route through `qs_manager.sh toggle <panel> top` — the `top` subtarget anchors the Quickshell panel just under this bar instead of above the bottom bar (see `QUICKSHELL.md`).

**`battery`** *(laptop)* — Icon + capacity; charging/plugged variants; `format-alt` shows time remaining. States: good ≥95, warning ≤30, critical ≤15 (blinks red).

## Helper scripts

**`waybar-sysinfo`** — CPU% from two `/proc/stat` samples 0.5s apart, MEM% from `/proc/meminfo`, and CPU package temperature. The thermal zone is found by **type** (`x86_pkg_temp` / `k10temp` / `coretemp`) rather than a fixed `thermal_zone*` index, so it survives kernel/hardware reshuffles instead of silently reading `0°C`.

**`waybar-gpu`** — GPU utilization and temperature via `nvidia-smi`; prints `?` if the query fails.

## Styling

Inline CSS in the `style` block. Palette is hard-coded Gruvbox Material Dark hex (not Stylix-driven). Conventions:

- Bar: `rgba(40,40,40,0.9)` background, 34px tall, 4px module spacing.
- Each right-hand module is a rounded pill (`#3c3836`, `border-radius: 8px`, `5px` vertical margin); `tray` is the exception (transparent).
- Per-module accent colors set foreground only (clock amber, mic blue, network green, GPU orange, etc.).
- `battery.critical` and similar use a `@keyframes blink` animation.
- Tooltips: dark `#282828` with a teal border.

## Changing things

| Want to… | Where |
|---|---|
| Add/remove a module | `modules-left/center/right` arrays + a matching settings block |
| Restyle a module | the `style = ''…''` CSS block (match the existing pill + accent pattern) |
| Change colors globally | edit the hex values in the style block (no theme variable indirection) |
| Adjust a per-host module | the `lib.optional (machineType == …)` lines |

After edits: `nixup` (or `nixos-rebuild dry-build --flake /etc/nixos#<host>` to validate without switching).
