# Desktop shells

Two shells are installed and swapped with `SUPER+ALT+1` / `SUPER+ALT+3`
(`SUPER+ALT+S` cycles). They are mutually exclusive systemd user units — both
register `org.freedesktop.Notifications` — wired up in
`modules/home/wm/shell-switcher.nix` and driven by
`config/hypr-scripts/shell-switch.sh`.

| | Own | DMS |
|---|---|---|
| Key | `SUPER+ALT+1` | `SUPER+ALT+3` |
| Unit | `shell-own.service` | `shell-dms.service` |
| Source | `config/hypr-scripts/quickshell/` | `dms-shell` 1.6.2 (unstable's recipe on stable Qt — `overlays/default.nix`) |
| Size | 21 panels, 25 QML files, ~7,350 lines | — |
| Bar | Waybar (separate unit) | built in |
| Shape | panels only, opened on demand | complete shell |

Noctalia was the third shell (`SUPER+ALT+2`) until 2026-09; it was removed
from the config. A machine whose recorded shell is still `noctalia` falls back
to `own` (`shell-switch.sh current`).

## Panel parity

What DMS has against each panel in `config/hypr-scripts/quickshell/`.

| Own panel | DMS |
|---|---|
| `AudioMixer` | ✅ |
| `BatteryPanel` | ✅ |
| `BluetoothPanel` | ✅ |
| `ClipboardPanel` | ✅ popout + `dms clipboard` CLI |
| `ControlCenter` | ✅ |
| `DiskPanel` | ✅ |
| `InputPanel` | ❌ |
| `KDEConnectPanel` | ❌ |
| `KeybindCheatSheet` | ✅ `dms keybinds` + cheatsheet UI |
| `KeyboardPanel` | ⚠️ `keyboard_layout_name` bar widget — click cycles via `hyprctl switchxkblayout`; no switcher page, untested here |
| `MonitorManager` | ⚠️ Settings → Displays → Configuration applies live, session-only (patched — see below); permanent layout stays in `monitors.lua` |
| `NetworkPanel` | ✅ |
| `NixPanel` | ❌ updater is pacman/dnf family only |
| `NotificationCenter` | ✅ |
| `NotificationToast` | ✅ |
| `Osd` | ✅ |
| `PowerMenu` | ✅ |
| `ScreenshotOverlay` | ✅ quickCapture plugin: region/window/output/all/last/scroll, editor, OCR, QR, recording |
| `SysInfoPanel` | ✅ |
| `WallpaperPicker` | ✅ |
| `WorkspaceOverview` | ✅ WorkspaceOverlays |

**No DMS counterpart:** `NixPanel`, `MonitorManager`, `KDEConnectPanel`,
`InputPanel`.

Extras DMS adds that the own panels don't have: an app launcher, a lock
screen, a dock, a notepad, a printer tab and a window-rules editor.

## Utility mode — keeping the own panels under DMS

The only thing that makes `Shell.qml` exclusive is
`org.freedesktop.Notifications`; the panels themselves collide with nothing. So
it runs *alongside* DMS as `shell-utility.service` — the same QML with
`QS_UTILITY_MODE=1`, which skips the notification server (behind a `Loader`),
the OSD and the waybar bridge. Every panel keeps working, so
`SUPER+I/N/Tab/Shift+V/Print` behave the same under both shells.

```
own → shell-own.service (+ waybar)
dms → shell-dms.service (+ shell-utility.service)
```

It `Conflicts` with `shell-own.service` rather than joining the shell units,
so exactly one `Shell.qml` runs at a time — `qs_manager.sh` addresses it by
config path, and a second instance would make that IPC ambiguous. The zombie
watchdog in that script starts whichever of the two fits the selected shell.

This recovers `NixPanel`, `MonitorManager`, `KDEConnectPanel` and `InputPanel`
under DMS.

## This config's incompatibilities

Three things about this setup that DMS does not expect.

### Lua dispatch

Hyprland here is configured by `config/hypr/hyprland.lua` and evaluates IPC
dispatch requests as Lua. DMS 1.4.6 hardcoded classic dispatcher strings
(`dispatch "workspace 3"` died with `')' expected near '3'`) and needed ten
call sites rewritten. 1.6 routes every dispatch through
`Services/HyprlandService.qml` and speaks Lua itself when the compositor is on
it.

One gap remains, patched in `modules/home/wm/shell-switcher.nix` with
`substituteInPlace --replace-fail` (a version bump that rewords a call site
fails the build rather than silently restoring dead clicks): window targets
must go through `hl.get_window("address:0x…")`, and DMS passes a bare address
string, which is accepted and does nothing. Three functions — focus, close,
move — cover the overview and window switcher.

Left as upstream: DMS's `dpmsOff`/`dpmsOn` now send
`hl.dsp.dpms({ action = … })`, but `hl.dsp.dpms` has been seen to ignore its
argument and toggle. Only DMS's own monitor-off timeouts call them, and those
are 0 here; hypridle owns blanking (and `config/hypr-scripts/wake-monitors.sh`
the absolute "on").

### Monitor configuration

DMS's Settings → Displays → Configuration page persists by writing
`~/.config/hypr/dms/outputs.lua` and reloading, relying on `hyprland.lua` to
load that file. Here `hyprland.lua` is a read-only store symlink whose monitors
come from `monitors.lua` and never loads it — so upstream, every Apply snapped
straight back.

`shell-switcher.nix` patches `DisplayConfigState.qml` so Apply (and revert)
go live over wlr-output-management instead (`WlrOutputService.outputsConfigHeads`
+ `applyConfiguration`, which 1.6 uses for its Aqueous compositor but not
Hyprland). Changes are
session-only: position, mode, scale, rotation and VRR apply and last until
the next `hyprctl reload` or login. The page's 10-second keep/revert dialog
still guards it, and revert is live too. Hyprland-only extras (bit depth,
HDR, colour management) go nowhere. The include warning box, which offers to
edit `hyprland.lua`, is hidden. Lasting changes belong in
`monitors.lua` / the host config; `MonitorManager` (own shell) is the other
working UI.

### NixOS

DMS's SystemUpdater knows `yay`, `paru`, `pacman` and `dnf` across the arch and
fedora families only, so it is inert here. `NixPanel` — `/nix` store gauge plus
a streaming `nh os switch` — has no counterpart in DMS (the `nixMonitor`
plugin covers part of it).

## Theming

Both are Gruvbox Material Dark from `config/stylix/palette.nix`, rendered
through `config/stylix/palette-subst.nix` at build time:

| Shell | Template | Deployed to |
|---|---|---|
| Own | `config/hypr-scripts/quickshell/Theme.qml` | store symlink |
| DMS | `config/dms/gruvbox-material.json` | `~/.config/DankMaterialShell/` |

DMS needs `currentThemeName = "custom"` before it reads `customThemeFile`.

Pointing DMS at its scheme is *not* declarative: `settings.json` is
owned and rewritten by the shell itself, so a store symlink would cost it every
setting it tries to save. An activation script in `shell-switcher.nix` merges
only those keys with `jq` and leaves the rest alone.

## Declarative configuration

Bar layouts mirror `modules/home/wm/waybar.nix` and are declared in
`shell-switcher.nix`, applied by the same `jq` merge as the theme keys. Portrait
and landscape outputs come from the shared `modules/home/wm/outputs.nix`, so
every bar trims the same screen waybar does.

DMS doesn't have a full set of counterparts:

- no scratchpad, rebuild (`NixPanel`) or keybinds widget
- no volume / network / bluetooth bar widgets at all — they live behind its
  control-centre button
- camera and mic fold into one `privacyIndicator`; recording has no home

Declaring widget lists means per-widget tweaks made in DMS's own GUI are
overwritten on the next `nixup` — the arrays are replaced, not merged.

DMS bars can't be replaced wholesale: a `barConfig` carries styling (spacing,
transparency, corners) alongside its widget arrays. The merge rewrites the
widget lists in place and clones bar 0 for the portrait output, so styling
survives. Verified idempotent.

`config/dms/BarSystemMonitor.qml` is installed over DMS's `CpuMonitor.qml`, so
the `cpuUsage` slot (and its click-through to the process list) renders one
pill for CPU, memory and GPU: each a Nerd Font icon (chip, RAM stick,
expansion card) plus a thin usage gauge, after
Noctalia's SystemMonitor in compact mode, with CPU and GPU temperature as text
and exact figures, plus root filesystem usage, in the tooltip. GPU data comes from `nvtop -s`
(installed everywhere by `productivity.nix`), which reads NVIDIA, AMD and Intel
without root: the discrete GPU wins where there is one, so the laptops show
their integrated GPU (a gauge with no temperature — Intel iGPUs don't report
one). `cpuTemp`, `memUsage`, `gpuTemp` and `diskUsage`
are left off the bar.

Two more DMS widgets are patched after Noctalia's (the former third shell): the system tray
treats every icon as hidden, so the bar shows only DMS's overflow chevron and
the icons open in its popup (a drawer); and the focused window shows its app
icon instead of the app name on horizontal bars, falling back to the name when
the icon can't be resolved. The media pill also shows the track's album art
as a small thumbnail in place of the visualiser, when the player provides it.

DMS ships `showWorkspaceIndex = false` — unlabelled dots — while waybar numbers
its workspaces, so it is declared on.

Weather needs a location, and DMS ships none. Waybar's
`custom/weather` calls `wttr.in` with no location at all and lets it geolocate
by IP, so auto-locate is the faithful mirror (`location.autoLocate` /
`useAutoLocation`), and it keeps a home address out of a public repo. DMS caches
resolved coordinates into its own SessionData.

## Bar transparency and caffeine

Both run a transparent bar with opaque widget capsules. Waybar's
`window#waybar` was already `background: transparent`; DMS reads `barConfig.transparency` straight into the background alpha despite
the name, so `0` is fully transparent and `widgetTransparency = 1` keeps the
pills.

The idle inhibitor starts on. Waybar has `start-activated` natively, but DMS
doesn't persist its toggle at all, so each shell unit's `ExecStartPost` runs
`shell-switch.sh started <name>`, which enables DMS's over IPC
(`inhibit enable`) — backgrounded and retried,
since the process isn't listening the moment it's spawned. Doing it from the
unit rather than the switcher means it holds however the shell was started.

## Wallpaper

`awww` is the single wallpaper owner. Every output gets the leaves at login
from the generated `wallpaper.lua`, then `shortcuts-wallpaper.sh` renders
`SHORTCUTS.md` into a cheat-sheet over the rotated secondary.

**Hotplug.** awww re-attaches a returning output with the last image set for
*all* outputs — the leaves — so unplugging the portrait monitor used to drop
the cheat-sheet for the rest of the session. A `monitor.added` handler in
`hyprland.lua` runs `wallpaper-redress.sh`, which checks which image the output
is actually displaying (it isn't bare, it's wrong) and only acts on rotated
outputs. The handler lives at top level rather than in `wallpaper.lua`, which
is only required inside `hyprland.start` and so wouldn't survive a reload.

**Render cache.** `shortcuts-wallpaper.sh` reuses its last PNG when neither
source changed. Store files all have mtime 1970, so `-nt` can't see an edit;
it stamps the resolved store paths of `shortcuts.md` and `.css` instead, which
a `nixup` repoints. A cache hit is ~0.06s against a headless-Chrome render.

**DMS** gets `screenPreferences.wallpaper = []`, exactly what its "Disable
Built-in Wallpapers" toggle writes, so a pick can never draw over awww. Its
picker still works: `dms-wallpaper-bridge.path` watches DMS's `session.json`
and `dms-wallpaper-bridge.sh` applies the pick through awww. A global pick
skips portrait outputs to keep the cheat-sheet; a per-monitor pick is honoured
as given. The dedupe stamp lives in `$XDG_RUNTIME_DIR` so a pick re-applies
once after login instead of losing to the leaves.

## DMS plugins

Declared in `modules/home/wm/dms-plugins.nix` rather than installed with
`dms plugins install`: each plugin is a store path symlinked into
`~/.config/DankMaterialShell/plugins/`, turned on through the same `jq` merge
into `plugin_settings.json`, and pinned by the `dms-plugin-registry` flake
input (its `nix/default.nix` carries a rev and hash per plugin). Hand-installed
plugins still work alongside.

| Plugin | Kind | Hosts |
|---|---|---|
| `nixMonitor` | bar — snowflake-only pill; popout has store size (sum of narSize, not `df`), generations, `nh os switch` / `nh clean user` | all |
| `dankKDEConnect` | bar + control centre | all |
| `claudeUsage` | bar — Claude Code limits, via `api.anthropic.com` only; patched to lead with the Claude Code logo (Simple Icons, pinned) and tightened | all |
| `nixPackageRunner` | launcher — `nix search` / `nix run` | all |
| `dankHyprlandWindows` | launcher — window switcher | all |
| `dankscale` | bar + control centre, Tailscale | tailscale hosts |

The main bar reads workspaces · focused window | music · clock · weather |
system monitor · `dankKDEConnect` (icon patched to `phonelink`) · `claudeUsage`
(logo + two rings, no percentages) · `dankscale` · `nixMonitor` · tray… The
centre has an odd count with the clock in the middle, which DMS's "index"
centring mode pins to the exact centre. The plugin pills only fit on the right
once Claude and Nix Monitor were cut down to icon size; at full size they ran
that section into the centre group.

A rebuild that changes any plugin clears `~/.cache/quickshell/qmlcache`: Qt
keys its compiled-QML cache on file path and mtime, and both are unchanged
across rebuilds (same `plugins/<id>/` path, store mtime 1970), so DMS otherwise
keeps running the old version of an edited plugin.

Every plugin comes from the `dms-plugin-registry` input's Nix package set.
`dankHyprlandWindows` is patched to pass windows through `hl.get_window()`. `nixMonitor`'s pill is patched to show the NixOS snowflake (and a status icon
when update checking is on — it is off here, with generations and store size,
via `plugin_settings.json`). `nixMonitor` reads its commands from
`plugins/NixMonitor/config.json`, which is built into the plugin directory.

Plugin popouts are patched to keep their content loaded after the first open.
Upstream rebuilds a plugin's popout on every click and then resizes the surface
to the new content, which made every open lag; built-in popouts are unchanged.

Left out on purpose: `displaySettings` (eval-disabled outputs need
`hyprctl reload` to come back), `displayProfile` (writes `hyprland.conf`),
`ddcBrightness` (DMS already does DDC/CI), `dockerManager` (tried, dropped), `nvidiaGpuMonitor` (replaced by the system monitor pill), `hyprlandSubmap` (no submaps here),
`keybindingCheatSheet` (parses `hyprland.conf`), `screenRecorder`
(quickCapture records too), `dmsScreenshot` (tried; no editor).

`quickCapture` has no bar pill and no Control Center tile. Print runs
`dms ipc call quickCapture showPicker`, a command `dms-plugins.nix` adds to the
plugin: it shows the plugin's bar menu (capture modes, outputs, recording) as a
floating, centred window, hosted by `config/dms/QuickCapturePicker.qml`. Its
recording, PDF, OCR and QR tools are in `home.packages`.

## Known issues

**Recorded shell follows systemd.** `shell-ipc.sh` routes keys by the recorded
shell, and that record used to be written only by the switcher — so starting a
unit any other way (`systemctl --user restart shell-dms.service`, or
`shell-restore` after a `nixup`) left it naming the previous shell. Keys then
went to a shell that wasn't running: Print opened the own screenshot panel
under DMS, and caffeine never came on. The same `ExecStartPost` now records
the name, so the file tracks whatever is actually up.

**DMS opened bar popouts on the wrong monitor** (fixed upstream in 1.6).
`getPreferredBar`'s `break` only left the inner of two loops, so with the
separate portrait bar `SUPER+W`, the dash and the control centre all landed on
DP-2. Patched here until 1.6 flattened the loop.

**Optional DMS dependencies** (`dms doctor`):

- `dgop` — installed. DMS's CPU, memory, temperature and disk widgets and its
  process list read from it; `dms-shell` doesn't depend on it, so without it
  they're blank.
- `matugen` — deliberately absent. DMS ships its matugen templates switched on
  for kitty, Hyprland, Qt5ct/Qt6ct, GTK, Firefox, Zen and more; installed, it
  would try to write generated themes over configs `palette.nix` and Stylix
  already own.
- `accountsservice` — not enabled. Only feeds DMS the user's avatar and display
  name.

**Wallpaper directory.** `~/Pictures/Wallpapers` is what every picker
defaults to — the own WallpaperPicker's `$WALLPAPER_DIR` fallback and DMS's —
and it didn't exist, so they all listed nothing. An
activation in `hyprland.nix` now creates it and seeds a real copy of the leaves
(not a symlink: the thumbnail scan uses `find -type f`). It only seeds on first
creation, so removing the image isn't undone by the next `nixup`.

**Harmless log noise:** DMS failing to register as polkit agent
(polkit-gnome already is), `$SWAYSOCK`/`$I3SOCK` unset, no `dms-colors.json`
(matugen output), and background blur unsupported on Hyprland.

## Known-untested

`hl.dsp.exit()`, DMS's log-out path. Correct by the API's shape, but verifying
it costs the session.
