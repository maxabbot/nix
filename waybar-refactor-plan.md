# Waybar-first shell refactor: vertical-monitor bar, kill Quickshell bar, tabbed Settings panel

## Context

The desktop currently runs two bars: Waybar on top (status modules) and a Quickshell bottom bar (MediaPlayer, keybinds button, rebuild spinner, notification bell). The portrait monitor (DP-2, 4K transform-1, 1440 logical px wide) gets the same crowded Waybar layout as the landscape monitors. The goal is to consolidate to **Waybar only**:

1. A second, slim Waybar layout on vertical monitors (derived generically from the per-host monitor strings).
2. Notification bell + keybind-cheat-sheet buttons move from the Quickshell bar to Waybar.
3. The Quickshell bottom bar is removed entirely (Quickshell keeps running headless as notification daemon + panel host).
4. MPRIS controls and the nix-rebuild indicator move to Waybar (built-in `mpris` module + a custom module).
5. A new **tabbed Settings panel** in Quickshell (⚙ button on Waybar) absorbs the six standalone panels: Control, Audio, Monitors, Wallpaper, Sysinfo, Nix. Existing Waybar module clicks deep-link to the matching tab. NotificationCenter, KeybindCheatSheet, ClipboardPanel, ScreenshotOverlay stay standalone.

User-approved decisions: slim **horizontal top bar** on DP-2 (not a side bar); **tabbed** settings panel (not a hub menu); **both** MPRIS and rebuild spinner move to Waybar.

## Verified facts the design relies on

- `waybar.nix` already reads `config.custom.hm`, which includes `monitors.{primary,secondary,tertiary}` (options in `modules/home/wm/hyprland.nix:118-139`) — no flake/hmArgs plumbing needed. `vm` (landscape only) and `work-laptop` (null monitors, kanshi) naturally yield no portrait outputs.
- Pinned `pkgs.unstable.waybar` is v0.15.0: supports `mpris`, `hide-empty-text`, `output` negation (`"!DP-2"`), multiple named bars, and `signal` + `interval: "once"` custom modules.
- `BarButton.qml` and `MediaPlayer.qml` are referenced only by `Bar.qml`; `Workspaces.qml` is referenced by nothing (verified by grep) — all deletable.
- Shell.qml's `subtarget` is only used as an edge selector today; qs_manager.sh's `TARGET_THUMB` and `NETWORK_MODE_FILE` writes are dead code (WallpaperPicker self-detects via `awww query`; nothing reads the mode file). `subtarget` is freed to carry the Settings tab name.
- Only keybind affected: `hyprland.lua:220` `SUPER+N → qs_manager.sh toggle notifications` (no subtarget) — keeps working unchanged.
- `Theme.qml`: `panelGapTop` (38) survives; `barBg`, `barHeight`, `panelGap` become orphans to remove.

## Phase A — Quickshell (all of `config/hypr-scripts/quickshell/` + `qs_manager.sh`)

### A1. Convert six panels from windows to embeddable pages (modify in place, keep filenames)

`ControlCenter.qml`, `AudioMixer.qml`, `SysInfoPanel.qml`, `MonitorManager.qml`, `WallpaperPicker.qml`, `NixPanel.qml`:
- Root `PanelWindow { anchors/margins/implicitWidth/Height }` → plain `Item`; delete the `edge` property and the outer chrome Rectangle (radius/border) — the Settings window provides chrome.
- Keep properties/signals: ControlCenter's `dndEnabled`/`dndToggled()`, NixPanel's `rebuildStarted`/`rebuildFinished(bool)`.
- Existing `Process`/`Timer` polling is already `visible`-gated; `StackLayout` sets `visible: false` on non-current pages, so polling stays cheap.
- Fix fixed-size math: MonitorManager's hardcoded `(760 - 32)` preview scale → `width - 32`; WallpaperPicker's `root.height - 70` ScrollView math → anchor/ColumnLayout based.

### A2. New `Settings.qml` (the only new PanelWindow)

Top-right dropdown (`anchors { top; right }`, `margins.top: Theme.panelGapTop`, ~780×620, `Theme.radiusPanel` chrome). Structure:
- `property string currentTab` + `readonly property var tabs: [ {id:"control",…}, audio, monitors, wallpaper, sysinfo, nix ]`.
- RowLayout: sidebar (Repeater over `tabs`, Gruvbox active/hover states via `Theme.accentBg`/`Theme.border`) | 1px divider | `StackLayout { currentIndex: tabIndex }` containing the six page components in tab order.
- Forwards `dndEnabled`/`dndToggled` and `rebuildStarted`/`rebuildFinished` between Shell.qml and the Control/Nix pages.

### A3. Rewrite `Shell.qml`

- **Delete** the `Variants { … Bar … }` bottom-bar block, the `panelEdge` property, and edge logic in `togglePanel`.
- Replace the six standalone panel instances with one `Settings { visible: activePanel === "settings"; currentTab: root.settingsTab; … }` plus `property string settingsTab: "control"` (two-way synced via `onCurrentTabChanged`).
- **IPC handler with deep-linking + legacy compat**: `target == "settings"` → `subtarget` is the tab; legacy targets (`control|audio|monitors|wallpaper|sysinfo|nix`) → rewritten to `settings` with that tab (so old callers/binds keep working). Toggle semantics: re-click on same tab closes; different tab while open just switches. Guard: ignore subtargets that aren't valid tab ids (stale `"top"`/`"bottom"` callers fall back gracefully).
- **Waybar state bridge** (event-driven, no polling): on `notifCount` / `rebuildRunning` change (and `Component.onCompleted` for resync after restart), `Quickshell.execDetached` writes `$XDG_RUNTIME_DIR/quickshell/notif-count` and `…/rebuild`, then `pkill -RTMIN+8 waybar`. Both Waybar custom modules use `"signal": 8` + `"interval": "once"`.

### A4. Re-anchor surviving standalone panels

- `NotificationCenter.qml`, `KeybindCheatSheet.qml`: bottom-right → **top-right** (`anchors { top; right }`, `margins { top: Theme.panelGapTop; right: 4 }`).
- `ClipboardPanel.qml`, `ScreenshotOverlay.qml`, toast window: untouched.

### A5. Deletions & cleanup

- Delete `Bar.qml`, `BarButton.qml`, `MediaPlayer.qml`, `Workspaces.qml`.
- `Theme.qml`: remove `barBg`, `barHeight`, `panelGap` (final grep to confirm no references).

### A6. `qs_manager.sh`

- In the open/toggle branch, map request → prep tab: `settings`→`$SUBTARGET`, `control|network`→`control`, `wallpaper`→`wallpaper`; fire `handle_network_prep` for `control` (fixes BT scan never firing from Waybar today) and `handle_wallpaper_prep` for `wallpaper`; then forward the IPC call unchanged.
- Remove dead code: the `TARGET_THUMB`/`CURRENT_SRC` block and `NETWORK_MODE_FILE` write. Keep the `close` branch's BT-scan teardown. Stay shellcheck-clean.

## Phase B — `modules/home/wm/waybar.nix`

### B1. Portrait-output derivation (in `let`)

```nix
monitorStrings = lib.filter (m: m != null) [ cfg.monitors.primary cfg.monitors.secondary cfg.monitors.tertiary ];
isPortrait = s: let parts = lib.splitString "," s;
  in builtins.length parts >= 6 && builtins.elemAt parts 4 == "transform"
     && lib.elem (builtins.elemAt parts 5) [ "1" "3" ];
portraitOutputs = map (s: lib.head (lib.splitString "," s)) (lib.filter isPortrait monitorStrings);
hasPortrait = portraitOutputs != [ ];
```

### B2. Two bar definitions, shared modules

Hoist all module configs into a `commonModules` attrset merged into both bars (keeps them in sync).

- **mainBar** (`name = "main"`): current layout + `mpris` (after modules-left or first in right group) and trailing `custom/rebuild`, `custom/keybinds`, `custom/notifications`, `custom/settings`. When `hasPortrait`: `output = map (n: "!" + n) portraitOutputs`. When not: no `output` key → identical to today on vm/laptop.
- **slimBar** (`name = "portrait"`, only appended when `hasPortrait`): `output = portraitOutputs`; modules-left `hyprland/workspaces`, center `clock`, right `pulseaudio network custom/rebuild custom/notifications custom/settings` (drops window title, tray, mpris, idle_inhibitor, bluetooth, mic, disk, sysinfo/gpu, keybinds — fits 1440 px). Tray stays main-bar-only (avoids multi-SNI quirks).

### B3. New modules (in `commonModules`)

- `mpris`: `format = "{status_icon} {dynamic}"`, `dynamic-order = ["title" "artist"]`, `dynamic-len = 40`, hidden automatically with no players.
- `custom/notifications`: `exec` = writeShellScript reading `$XDG_RUNTIME_DIR/quickshell/notif-count`, JSON output `{"text":"󰂚 N","class":"has-notifs"}` / plain bell at 0; `return-type = "json"`, `interval = "once"`, `signal = 8`; `on-click = "${qs} toggle notifications"`.
- `custom/rebuild`: `exec` = script echoing `󱄅 building` iff `…/rebuild` file is non-empty, else empty; `hide-empty-text = true`, `interval = "once"`, `signal = 8`; `on-click = "${qs} toggle settings nix"`. CSS pulse animation replaces the braille spinner (no sub-second exec churn).
- `custom/keybinds`: static `󰌌`, `on-click = "${qs} toggle keybinds"`.
- `custom/settings`: static ``, `on-click = "${qs} toggle settings"`.

### B4. Retarget existing clicks (drop the obsolete `top` subtarget)

- bluetooth / network → `toggle settings control`
- pulseaudio / mic right-click → `toggle settings audio`
- disk / custom/sysinfo / custom/gpu → `toggle settings sysinfo`

### B5. CSS

Add `#mpris, #custom-notifications, #custom-keybinds, #custom-settings, #custom-rebuild` to the pill-group selector; accents: `#custom-notifications.has-notifs { color: #ea6962; }`, `#mpris { color: #89b482; }`, `#custom-rebuild { color: #d8a657; animation: pulse …; }` + `@keyframes pulse`.

## Phase C — `config/hypr/hyprland.lua` (small)

Add a parity bind: `SUPER+I → bash ~/.config/hypr/scripts/qs_manager.sh toggle settings` (use `hl.dsp.exec_cmd`, Lua dispatch syntax — classic strings fail silently). `SUPER+N` unchanged.

## Deploy

`git add -A` (new `Settings.qml` + deletions are invisible to the flake otherwise — known gotcha), run `nixup`, then restart quickshell (kill; `qs_manager.sh` watchdog respawns, or relaunch manually) and `systemctl --user restart waybar`.

## Verification

1. Eval all hosts: `nix flake check` (especially `work-laptop` null monitors, `minimal` compositor=none, `vm` single landscape).
2. home-desktop: main bar on DP-3 + HDMI-A-1 only; slim bar on DP-2 (`pgrep -af waybar`; inspect generated waybar config `output` arrays).
3. `notify-send test` → `󰂚 1` (red) appears instantly on both bars via RTMIN+8; clearing in NotificationCenter resets; survives waybar restart (file re-read) and quickshell restart (`Component.onCompleted` resync).
4. Settings: ⚙ toggles open/close; pulseaudio click → Audio tab; network click while open → switches to Control **and** starts BT scan + wifi rescan (`pgrep -f bluetoothctl`); close kills the scan; Wallpaper tab populates thumbs.
5. Nix tab rebuild → pulsing `󱄅 building` in Waybar, disappears on finish.
6. mpris: appears with a player, click play/pauses, hidden otherwise.
7. `SUPER+N` opens NotificationCenter top-right; keybinds button opens cheat sheet top-right; Clipboard/Screenshot unaffected.
8. `shellcheck config/hypr-scripts/qs_manager.sh`; `grep -rn "panelGap\b\|barBg\|barHeight\|BarButton\|MediaPlayer\|Workspaces" config/hypr-scripts/quickshell/` → empty; quickshell starts with a clean log (no missing-type/anchor warnings).

## Risks

- mpris module relies on nixpkgs waybar's playerctl flag (default-on; the patch override doesn't touch flags). Fallback: `custom/media` via playerctl.
- RTMIN+8 must stay unique among waybar `signal` users (none exist today).
- All six Settings pages instantiate at quickshell start — polling is visible-gated, cost negligible.
- Stale rebuild flag if quickshell dies mid-rebuild — mitigated by startup resync.
- `Bar.qml` has uncommitted local changes — deleting it discards them (they're bar-layout-only, superseded by this refactor).

## Files touched

| Action | Path |
|---|---|
| New | `config/hypr-scripts/quickshell/Settings.qml` |
| Rewrite | `config/hypr-scripts/quickshell/Shell.qml` |
| Page-ify | `ControlCenter.qml`, `AudioMixer.qml`, `SysInfoPanel.qml`, `MonitorManager.qml`, `WallpaperPicker.qml`, `NixPanel.qml` |
| Re-anchor | `NotificationCenter.qml`, `KeybindCheatSheet.qml` |
| Delete | `Bar.qml`, `BarButton.qml`, `MediaPlayer.qml`, `Workspaces.qml` |
| Trim | `Theme.qml` (drop barBg/barHeight/panelGap) |
| Edit | `config/hypr-scripts/qs_manager.sh`, `modules/home/wm/waybar.nix`, `config/hypr/hyprland.lua` |
