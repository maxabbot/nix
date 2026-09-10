# Desktop shells

Three shells are installed and swapped with `SUPER+ALT+1..3` (`SUPER+ALT+S`
cycles). They are mutually exclusive systemd user units — all three register
`org.freedesktop.Notifications` — wired up in
`modules/home/wm/shell-switcher.nix` and driven by
`config/hypr-scripts/shell-switch.sh`.

| | Own | Noctalia | DMS |
|---|---|---|---|
| Key | `SUPER+ALT+1` | `SUPER+ALT+2` | `SUPER+ALT+3` |
| Unit | `shell-own.service` | `shell-noctalia.service` | `shell-dms.service` |
| Source | `config/hypr-scripts/quickshell/` | `nixpkgs#noctalia-shell` 4.7.6 | `nixpkgs#dms-shell` 1.4.6 |
| Size | 21 panels, 25 QML files, ~7,350 lines | — | — |
| Bar | Waybar (separate unit) | built in | built in |
| Shape | panels only, opened on demand | complete shell | complete shell |

## Panel parity

What the two third-party shells have against each panel in
`config/hypr-scripts/quickshell/`.

| Own panel | Noctalia | DMS |
|---|---|---|
| `AudioMixer` | ✅ | ✅ |
| `BatteryPanel` | ✅ | ✅ |
| `BluetoothPanel` | ✅ | ✅ |
| `ClipboardPanel` | ✅ launcher clipboard mode | ✅ popout + `dms clipboard` CLI |
| `ControlCenter` | ✅ | ✅ |
| `DiskPanel` | ✅ SystemStats | ✅ |
| `InputPanel` | ❌ | ❌ |
| `KDEConnectPanel` | ❌ | ❌ |
| `KeybindCheatSheet` | ❌ | ✅ `dms keybinds` + cheatsheet UI |
| `KeyboardPanel` | ⚠️ displays layout, no switcher page | ❌ |
| `MonitorManager` | ❌ its `monitors` IPC is DPMS on/off only | ⚠️ full UI, but cannot apply here — see below |
| `NetworkPanel` | ✅ | ✅ |
| `NixPanel` | ❌ | ❌ updater is pacman/dnf family only |
| `NotificationCenter` | ✅ NotificationHistory | ✅ |
| `NotificationToast` | ✅ | ✅ |
| `Osd` | ✅ | ✅ |
| `PowerMenu` | ✅ SessionMenu | ✅ |
| `ScreenshotOverlay` | ❌ | ✅ `dms screenshot` region/window/output/all/last |
| `SysInfoPanel` | ✅ SystemStats | ✅ |
| `WallpaperPicker` | ✅ | ✅ |
| `WorkspaceOverview` | ❌ no exposé at all | ✅ WorkspaceOverlays |

**Irreplaceable under both:** `NixPanel`, `MonitorManager`, `KDEConnectPanel`,
`InputPanel`.

**Also missing under Noctalia:** `ScreenshotOverlay`, `KeybindCheatSheet`,
`WorkspaceOverview` — so `SUPER+Tab` and `Print` do nothing there.

Extras neither of these replaces, but which the third-party shells add: an app
launcher, a lock screen and a dock (both), plus a notepad, printer tab and
window-rules editor (DMS).

## Utility mode — keeping the own panels under the other shells

The only thing that makes `Shell.qml` exclusive is
`org.freedesktop.Notifications`; the panels themselves collide with nothing. So
it runs *alongside* Noctalia and DMS as `shell-utility.service` — the same QML
with `QS_UTILITY_MODE=1`, which skips the notification server (behind a
`Loader`), the OSD and the waybar bridge. Every panel keeps working, so
`SUPER+I/N/Tab/Shift+V/Print` behave the same under all three shells.

```
own      → shell-own.service      (+ waybar)
noctalia → shell-noctalia.service (+ shell-utility.service)
dms      → shell-dms.service      (+ shell-utility.service)
```

It `Conflicts` with `shell-own.service` rather than joining the three-way web,
so exactly one `Shell.qml` runs at a time — `qs_manager.sh` addresses it by
config path, and a second instance would make that IPC ambiguous. The zombie
watchdog in that script starts whichever of the two fits the selected shell.

This recovers `NixPanel`, `MonitorManager`, `KDEConnectPanel` and `InputPanel`
everywhere, plus `ScreenshotOverlay`, `KeybindCheatSheet` and
`WorkspaceOverview` under Noctalia.

## This config's incompatibilities

Three things about this setup that these shells do not expect.

### Lua dispatch

Hyprland here is configured by `config/hypr/hyprland.lua` and evaluates IPC
dispatch requests as Lua. Both third-party shells hardcode classic dispatcher
strings, so `dispatch "workspace 3"` dies with `')' expected near '3'` and
every workspace click is a silent no-op.

Fixed by the `luaDispatch` helper in `modules/home/wm/shell-switcher.nix`,
which rewrites the call sites with `substituteInPlace --replace-fail` at build
time — 5 in Noctalia, 10 in DMS. The `--replace-fail` is deliberate: a version
bump that rewords a call site fails the build rather than silently restoring
dead clicks. Same class of breakage as
`pkgs/waybar/hyprland-lua-dispatch.patch`.

Window targets must go through `hl.get_window("address:0x…")`; passing a bare
address string is accepted and does nothing.

Still classic on purpose: DMS's `dpms on` / `dpms off`. `hl.dsp.dpms` ignores
its state argument and only toggles, so a literal translation would blank
screens that are already on — worse than the current no-op. An absolute "on"
needs the per-monitor `dpmsStatus` logic in
`config/hypr-scripts/wake-monitors.sh`. Hypridle owns blanking here anyway.

### Monitor configuration

DMS's `DisplayConfig` tab persists by writing `~/.config/hypr/dms/outputs.conf`
and splicing `source = ./dms/outputs.conf` into `~/.config/hypr/hyprland.conf`.
This config has no `hyprland.conf` — it has `hyprland.lua`, deployed as a
read-only store symlink. Expect its "Outputs Include Missing" warning and a
failed write. `MonitorManager` remains the only working monitor UI.

### NixOS

DMS's SystemUpdater knows `yay`, `paru`, `pacman` and `dnf` across the arch and
fedora families only, so it is inert here. `NixPanel` — `/nix` store gauge plus
a streaming `nh os switch` — has no counterpart in either shell.

## Theming

All three are Gruvbox Material Dark from `config/stylix/palette.nix`, rendered
through `config/stylix/palette-subst.nix` at build time:

| Shell | Template | Deployed to |
|---|---|---|
| Own | `config/hypr-scripts/quickshell/Theme.qml` | store symlink |
| Noctalia | `config/noctalia/Gruvbox-Material.json` | `~/.config/noctalia/colorschemes/Gruvbox-Material/` |
| DMS | `config/dms/gruvbox-material.json` | `~/.config/DankMaterialShell/` |

Noctalia scans its scheme directory with `find -mindepth 2`, so its JSON must
sit in a subdirectory of its own and the basename becomes the display name.
DMS needs `currentThemeName = "custom"` before it reads `customThemeFile`.

Pointing each shell at its scheme is *not* declarative: `settings.json` is
owned and rewritten by the shell itself, so a store symlink would cost it every
setting it tries to save. An activation script in `shell-switcher.nix` merges
only those keys with `jq` and leaves the rest alone.

## Declarative configuration

Bar layouts mirror `modules/home/wm/waybar.nix` and are declared in
`shell-switcher.nix`, applied by the same `jq` merge as the theme keys. Portrait
and landscape outputs come from the shared `modules/home/wm/outputs.nix`, so
every bar trims the same screen waybar does.

Neither shell has a full set of counterparts:

- no scratchpad, rebuild (`NixPanel`) or keybinds widget in either
- Noctalia has no weather widget
- DMS has no volume / network / bluetooth bar widgets at all — they live behind
  its control-centre button
- DMS folds camera and mic into one `privacyIndicator`; recording has no home

Declaring widget lists means per-widget tweaks made in a shell's own GUI are
overwritten on the next `nixup` — the arrays are replaced, not merged.

DMS bars can't be replaced wholesale: a `barConfig` carries styling (spacing,
transparency, corners) alongside its widget arrays. The merge rewrites the
widget lists in place and clones bar 0 for the portrait output, so styling
survives. Verified idempotent.

Noctalia's `bar.monitors` defaults to `[]` on a fresh install, which renders no
bar at all and looks like a silent failure — it is declared here for that
reason.

Weather needs a location in both, and neither ships one — Noctalia logs
"Cannot fetch weather without coordinates" and stays blank. Waybar's
`custom/weather` calls `wttr.in` with no location at all and lets it geolocate
by IP, so auto-locate is the faithful mirror (`location.autoLocate` /
`useAutoLocation`), and it keeps a home address out of a public repo. Set
Noctalia's `location.name` to a city in `shell-switcher.nix` to pin it instead;
DMS caches resolved coordinates into its own SessionData.

## Wallpaper

`awww` is the single wallpaper owner. Noctalia stacked its own layer on top of
awww's rather than replacing it, so `wallpaper.enabled` is off, and
`useWallpaperColors` with it — otherwise the scheme above gets overridden by
colours derived from whatever is on screen. DMS needed no such fix: its
wallpaper layer resolves to `""` and draws nothing unless one is configured.

## Known-untested

`hl.dsp.exit()`, DMS's log-out path. Correct by the API's shape, but verifying
it costs the session.
