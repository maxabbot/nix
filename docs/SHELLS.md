# Desktop shell

The desktop shell is DMS (DankMaterialShell): bar, notifications, launcher,
control centre, settings and the rest. It runs as `shell-dms.service`, started
with the graphical session and declared in `modules/home/wm/dms.nix`
(DMS 2.0, which nixpkgs calls `dux-shell` — unstable's recipe on stable Qt,
see `overlays/default.nix`). The panel keybinds in `config/hypr/hyprland.lua` call
`dms ipc …` directly.

Until 2026-09-30 this config also carried its own Quickshell panels and a
Waybar bar, switchable against DMS (and, before that, Noctalia). They were
removed; DMS is the only shell. Four things went with them that DMS doesn't
replace one for one:

- **Input page** (tap to click, natural scroll, pointer sensitivity at
  runtime) — no counterpart; those are set in `hyprland.lua`.
- **Monitors page** with a saved layout (`monitors-local.lua`) — DMS's
  Displays page applies live but session-only (see below); lasting layout
  belongs in the host config.
- **Nix page** with a streaming `nh os switch` — the `nixMonitor` plugin has
  store size, generations, `nh os switch` and `nh clean user`.
- **Keyboard layout page** — DMS has a `keyboard_layout_name` bar widget that
  cycles layouts; not on the bar here.

## This config's incompatibilities

Three things about this setup that DMS does not expect.

### Lua dispatch

Hyprland here is configured by `config/hypr/hyprland.lua` and evaluates IPC
dispatch requests as Lua. DMS 1.4.6 hardcoded classic dispatcher strings
(`dispatch "workspace 3"` died with `')' expected near '3'`) and needed ten
call sites rewritten. 1.6 routes every dispatch through
`Services/HyprlandService.qml` and speaks Lua itself when the compositor is on
it.

One gap remains, patched in `modules/home/wm/dms.nix` with
`substituteInPlace --replace-fail` (a version bump that rewords a call site
fails the build rather than silently restoring dead clicks): window targets
must go through `hl.get_window("address:0x…")`, and DMS passes a bare address
string, which is accepted and does nothing. Three functions — focus, close,
move — cover the overview and window switcher.

Left as upstream: DMS's `dpmsOff`/`dpmsOn` now send
`hl.dsp.dpms({ action = … })`, but `hl.dsp.dpms` has been seen to ignore its
argument and toggle. Only DMS's own monitor-off timeouts call them, and those
are 0 here; hypridle owns blanking (and `config/hypr-scripts/dpms.sh`
the absolute "on").

### Monitor configuration

DMS's Settings → Displays → Configuration page persists by writing
`~/.config/hypr/dms/outputs.lua` and reloading, relying on `hyprland.lua` to
load that file. Here `hyprland.lua` is a read-only store symlink whose monitors
come from `monitors.lua` and never loads it — so upstream, every Apply snapped
straight back.

`dms.nix` patches `DisplayConfigState.qml` so Apply (and revert)
go live over wlr-output-management instead (`WlrOutputService.outputsConfigHeads`
+ `applyConfiguration`, which 1.6 uses for its Aqueous compositor but not
Hyprland). Changes are
session-only: position, mode, scale, rotation and VRR apply and last until
the next `hyprctl reload` or login. The page's 10-second keep/revert dialog
still guards it, and revert is live too. Hyprland-only extras (bit depth,
HDR, colour management) go nowhere. The include warning box, which offers to
edit `hyprland.lua`, is hidden. Lasting changes belong in
`monitors.lua` / the host config.

### Compositor layout settings

Settings → Compositor → Hyprland Layout Overrides had the same problem as
the Displays page, plus a side effect: upstream writes
`~/.config/hypr/dms/layout.lua`, which `hyprland.lua` never loads, then runs
`hyprctl reload`. The page changed nothing, and every regeneration (any
change to the bar's spacing, the corner radius or the page's settings — 13
on framework on 2026-11-05) reloaded Hyprland, dropping session-only state
such as the Displays page's live changes.

`dms.nix` patches `HyprlandService.qml` so only explicit overrides apply,
live over `hyprctl eval`: Custom gaps, the radius and border-size toggles,
and resize-on-border. Auto and Off keep `hyprland.lua`'s values (gaps 5/10,
rounding 10, border 2), and with no overrides set DMS no longer touches
Hyprland at all. Turning an override off reloads once to restore
`hyprland.lua`'s value. Like the Displays page it's session-only; DMS
re-applies overrides when it next starts. The two Xray toggles are hidden:
their layer rules can't be undone live, and `hyprland.lua` owns the `dms:*`
blur rules.

The cursor page (Theme & Colors → Cursor) had the same write-then-reload
shape over a `cursor.lua` nothing loaded, and gets the same treatment: an
explicit theme or size applies through `hyprctl setcursor`, the hide options
(on key press, on touch, after inactivity) through `hyprctl eval`, and going
back to the defaults restores the session's (Stylix's) cursor. Session-only.

The Window Rules page is different. Its rules are additions, not values
something in Nix declares, so `hyprland.lua` loads
`~/.config/hypr/dms/windowrules.lua`, after its own rules so DMS's win. The
require is wrapped (`pcall(function() require("dms.windowrules") end)`): the
file doesn't exist until DMS first runs, after Hyprland, and DMS's page greps
for the literal `require("dms.windowrules")` to report the rules as active.
DMS ships one rule there by default, which floats every DMS window.

### NixOS

DMS's SystemUpdater knows `yay`, `paru`, `pacman` and `dnf` across the arch and
fedora families only, so it is inert here. The `nixMonitor` plugin stands in:
store size, generations, `nh os switch` and `nh clean user`.

## Theming

Gruvbox Material Dark from `config/stylix/palette.nix`: the template
`config/dms/gruvbox-material.json` is rendered through
`config/stylix/palette-subst.nix` at build time and deployed to
`~/.config/dms/`. (2.0 renamed its dirs from `DankMaterialShell/` to `dms/`;
`dms.nix` moves them on activation and leaves the old name as a symlink.)

DMS needs `currentThemeName = "custom"` before it reads `customThemeFile`.

Pointing DMS at its scheme is *not* declarative: `settings.json` is
owned and rewritten by the shell itself, so a store symlink would cost it every
setting it tries to save. An activation script in `dms.nix` merges
only those keys with `jq` and leaves the rest alone.

## Declarative configuration

Bar layouts are declared in `dms.nix` and applied by the same `jq` merge as
the theme keys. Portrait and landscape outputs come from
`modules/home/wm/outputs.nix`; a portrait output gets a trimmed bar.

What DMS's bar has no widget for:

- scratchpad count, rebuild and keybinds
- volume / network / bluetooth — they live behind its control-centre button
- camera and mic fold into one privacy indicator (now the island's privacy
  group); recording has no home

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

Two more DMS widgets are patched after Noctalia's (a shell tried here earlier): the system tray
treats every icon as hidden, so the bar shows only DMS's overflow chevron and
the icons open in its popup (a drawer); and the focused window shows its app
icon instead of the app name on horizontal bars, falling back to the name when
the icon can't be resolved. Media has no pill of its own any more: the
Dynamic Island (below) shows the playing track.

DMS ships `showWorkspaceIndex = false` — unlabelled dots — so it is declared
on to number the workspaces. Since 2.0 it is an option on the
`workspaceSwitcher` widget entry, not a global key; the activation's `keep()`
leaves options set on a bar widget in DMS's GUI in place.

Weather needs a location, and DMS ships none. Auto-locate
(`useAutoLocation`) geolocates by IP, which keeps a home address out of a
public repo. DMS caches
resolved coordinates into its own SessionData.

## Bar transparency and caffeine

The bar is a transparent strip with widget capsules. DMS reads
`barConfig.transparency` straight into the background alpha despite the name,
so `0` is fully transparent; `widgetTransparency` is the pills' alpha.

DMS persists its idle-inhibitor toggle as `idleInhibited` in
`~/.local/state/dms/session.json`, so it keeps whatever you last
chose. Nothing forces it on at startup, since that would override an "off".

DMS's inhibitor is a Wayland idle-inhibitor on its bar, and it doesn't survive
a resume reliably. DMS rebuilds the bar surfaces on wake, and hypridle then
locked 5 min later even though `dms ipc inhibit status` still said enabled. So
hypridle's lock, blank and suspend listeners are wrapped in `unlessCaffeine`
(`modules/home/wm/hyprland.nix`): they ask the IPC first and skip while
caffeine is on.

## Dynamic Island

DMS 2.0's island is the centre of both bars (the `island` entry in `dms.nix`).
Closed, it shows media · clock · weather · notifications · privacy, compact
size; while something plays it turns to the track. Clicked, it expands in
place into the Dash (calendar, weather, media, notifications). It also takes
notification popups, expanded by default, and the volume/brightness OSDs.

DMS hosts an island in a normal bar as a guest of the bar strip, and almost
every default there assumed an opaque strip and a compositor that doesn't
animate layer resizes. Each fix is a `dms.nix` patch or setting, commented at
the site:

- **See-through.** In a normal bar the island draws "band" chrome, the bar
  strip's own colour, which is alpha 0 here. Patched to its own chrome
  (`DBarBody.qml`) at the popout alpha (`IslandBarHost.qml`), so it's blurred
  like any other panel. Own chrome is placed by its own edge gap, not the
  bar's spacing: `islandOuterGap = 8` lines it up with the pills.
- **Flicker.** Opening it moved the whole bar from the Top layer to Overlay
  and resized its surface, and each blanked the bar for a frame. Patched to
  stay on Top (`DBarWindow.qml`) and keep the open island's height for good
  (`DBarBody.qml`, ~690px on a 1440p output). Clicks are unaffected: the
  input mask is the strip plus the island, not the window. Hyprland
  animating the resize stretched every pill, hence the `no_anim` layer rule
  on `dms:bar` in `hyprland.lua`.
- **Brightness OSD.** DMS shows it for any change, so Clight popped the
  island every few seconds. Patched to show it only for changes DMS makes
  (`BrightnessService.qml`); the brightness keys go through
  `dms ipc call brightness` for that reason. DMS's percentage scale is offset
  (raw = (pct − 1)/99 × max, so its 1% is a black panel), hence a 4% floor
  for backlights, which is 3% raw like Clight's curves.
- **Media auto-switch** fired only when a player appeared; a paused player
  already counts, so play/pause never switched it. Patched to follow
  playback (`IslandMediaSource.qml`, `IslandController.qml`): playing shows
  the track, pausing goes back to the clock.
- Spring damping 48 (critically damped; DMS's 37 overshoots), and Chrome's
  "Activate" default-action button relabelled "Open" (`NotificationCard.qml`,
  `IslandNotificationSource.qml`).

Two settings read backwards: `islandNotificationPopups = false` is what routes
notifications *into* the island, and `islandSystemOsd = true` gives it the
OSDs.

**Checking a patch before deploying it.** Every patch above went in after
being run live: build the host, pick the patched `dux-shell` out of the
closure, stop `shell-dms` and run `<pkg>/bin/dms run --session` under
`systemd-run --user` with the session's Wayland/Hyprland env, drive it with
`dms ipc call island openOn home <output>` / `toggleOn` (plain `close` only
closes the focused output's island), then restart `shell-dms`. `wf-recorder`
at 60fps plus a frame diff is what found the flicker and its causes; a
screenshot shows nothing wrong. A DMS update that changes any patched line
fails the build (`--replace-fail`), which is the cue to re-check that fix.

## Wallpaper

`awww` is the single wallpaper owner. Every output gets the leaves at login
from the generated `wallpaper.lua`, then `shortcuts-wallpaper.sh` renders
`SHORTCUTS.md` into a cheat-sheet over the rotated secondary. A host can set
`wallpaperPortrait` (hmArgs) to put an image there instead — home-desktop does;
`wallpaper-redress.sh` then restores that image on hotplug, not the cheat-sheet.

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
`~/.config/dms/plugins/`, turned on through the same `jq` merge
into `plugin_settings.json`, and pinned by the `dms-plugin-registry` flake
input (its `nix/default.nix` carries a rev and hash per plugin). Hand-installed
plugins still work alongside.

| Plugin | Kind | Hosts |
|---|---|---|
| `nixMonitor` | control centre — a tile patched in (upstream is bar-only): generations · store size, highlighted past the GC threshold, opening upstream's popout as its detail page, which has store size (sum of narSize, not `df`), generations, `nh os switch` / `nh clean user` | all |
| `dankKDEConnect` | bar + control centre | all |
| `claudeUsage` | bar — Claude Code limits, via `api.anthropic.com` only; patched to lead with the Claude Code logo (Simple Icons, pinned) and tightened; its popout gains an account switcher (`config/dms/ClaudeAccounts.qml`) over the logins saved with `claude-account` | all |
| `nixPackageRunner` | launcher — `nix search` / `nix run` | all |
| `dankHyprlandWindows` | launcher — window switcher | all |
| `dankscale` | control centre (its bar pill unused) — tap toggles Tailscale, the chevron opens the bar popout as a detail page (patched in), Tailscale | tailscale hosts |
| `deviceBatteries` | bar — lowest peripheral battery (UPower: Bluetooth mice/headsets; Solaar's library for receiver-only Logitech), hidden when no device reports one; its helper runs on a Python env with Solaar, dbus-python, pygobject and pyudev (patched in for the bare `python3`) | all |

The main bar reads workspaces · focused window | Dynamic Island |
system monitor · `dankKDEConnect` (icon patched to `phonelink`) · `claudeUsage`
(logo + two rings, no percentages) · device batteries (only with a device) ·
battery · tray · control centre. Dankscale, Nix Monitor and the idle inhibitor
are Control Center tiles instead; notifications and privacy live in the
island. The island is the centre's only entry, which DMS's "index" centring
mode pins to the exact centre. The plugin pills only fit on the right once
Claude was cut down to icon size; at full size it ran that section into the
centre.

A rebuild that changes any plugin clears `~/.cache/quickshell/qmlcache`: Qt
keys its compiled-QML cache on file path and mtime, and both are unchanged
across rebuilds (same `plugins/<id>/` path, store mtime 1970), so DMS otherwise
keeps running the old version of an edited plugin.

Every plugin comes from the `dms-plugin-registry` input's Nix package set.
`dankHyprlandWindows` is patched to pass windows through `hl.get_window()`. `nixMonitor`'s pill (unused, as above) is patched to show the NixOS snowflake (and a status icon
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

`quickCapture` has no bar pill, only a Control Center tile. Print runs
`dms ipc call quickCapture showPicker`, a command `dms-plugins.nix` adds to the
plugin: it shows the plugin's bar menu (capture modes, outputs, recording) as a
floating, centred window, hosted by `config/dms/QuickCapturePicker.qml`. Its
recording, PDF, OCR and QR tools are in `home.packages`.

## Known issues

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

**Wallpaper directory.** `~/Pictures/Wallpapers` is what DMS's picker
defaults to, and it didn't exist, so it listed nothing. An
activation in `hyprland.nix` now creates it and seeds real copies of every
wallpaper in the repo (`wallpaperSeeds`: leaves, waterfall, cave, and the
rainbow Nix and Framework logos). Each is seeded once per machine and noted in
the folder's `.seeded`, so removing an image isn't undone by the next `nixup`,
but a newly added one still arrives.

**Harmless log noise:** DMS failing to register as polkit agent
(polkit-gnome already is), `$SWAYSOCK`/`$I3SOCK` unset, no `dms-colors.json`
(matugen output), and background blur unsupported on Hyprland.

## Known-untested

`hl.dsp.exit()`, DMS's log-out path. Correct by the API's shape, but verifying
it costs the session.

The island on home-desktop: the portrait bar's island, and whether one
notification or OSD pops the islands on both outputs at once (each bar hosts
its own). Built and evaluated, not yet run there.
