# Quickshell

Panel/overlay layer for the Hyprland hosts: notification server (replaces swaync), OSD, power menu, workspace overview, screenshot picker, clipboard history, and a tabbed **Settings** panel. Waybar (`WAYBAR.md`) is the only bar — the old Quickshell bottom bar was removed in the Waybar-first refactor. Entry point: `config/hypr-scripts/quickshell/Shell.qml`. Managed by `config/hypr-scripts/qs_manager.sh`.

## Components

**`Theme.qml`** — `pragma Singleton` holding the Gruvbox Material Dark palette, the UI font (`JetBrainsMono Nerd Font`), and shared metrics. Every component references colours/fonts as `Theme.<token>` (e.g. `Theme.bg`, `Theme.accent`, `Theme.font`) — no `import` needed, it resolves by same-directory registration. Base colours are `@token@` placeholders rendered at build time from `config/stylix/palette.nix`. Change a colour here once and it updates across the whole shell.

**`Shell.qml`** — Entry point. Owns all global state (`activePanel`, `settingsTab`, `dndEnabled`, `rebuildRunning`), the `IpcHandler` for `qs_manager.sh` commands (with legacy-target → Settings-tab rewriting), the `NotificationServer` (D-Bus `org.freedesktop.Notifications`), the transient toast window, and the Waybar state bridge — on every `notifCount`/`rebuildRunning` change it writes `$XDG_RUNTIME_DIR/quickshell/{notif-count,rebuild}` and pokes Waybar with `RTMIN+8` (event-driven, no polling).

**`NotificationCenter.qml`** — Scrollable notification history (top-right, drops from Waybar). Shows all current notifications with dismiss and clear-all. Fed the `NotificationServer`'s model from Shell.

**`NotificationToast.qml`** — Transient top-right toast for incoming notifications. Used in the repeater inside Shell's toast `PanelWindow`. Dismiss/auto-expire call `notification.dismiss()` / `.expire()` (Quickshell's `Notification` has no `close()`).

**`Osd.qml`** — Transient bottom-centre on-screen display for volume / brightness. Presentational; Shell drives `kind`/`level`/`muted` and the ~1.6s auto-hide. Volume is observed passively from PipeWire (any change flashes it); brightness is push-triggered by the `osd brightness` IPC call from the brightness keybinds.

**`PowerMenu.qml`** — Fullscreen dimmed session overlay (replaces wlogout): Lock (`hyprlock`), Suspend, Logout (`uwsm stop`), Reboot, Shutdown. Esc or click-off dismisses; opened via `qs_manager.sh toggle power` (bound to `Super+Shift+E`).

**`WorkspaceOverview.qml`** — Fullscreen workspace exposé ("mission control"), opened via `qs_manager.sh toggle overview` (bound to `Super+Tab`). A grid of workspace tiles, each drawing its windows as geometry-accurate rectangles scaled from the real `hyprctl clients/monitors/workspaces -j` layout (per-window fractions computed against the owning monitor's logical size). Click a window to focus it (`dispatch focuswindow address:…`), click a tile's empty canvas to switch to that workspace (`dispatch workspace`); the focused workspace is accent-ringed. State is parsed once per open and lightly re-polled (1.5s) — not live screencopy thumbnails, which Quickshell 0.3.0 can't map to individual toplevels. Esc / click-off closes.

**`ClipboardPanel.qml`** — Centred cliphist history modal (`Super+Shift+V`) with hover-to-expand rows. On open, `clipboard-prep.sh` emits one JSON line per history entry (images decoded to thumbnail files, text in full). Clicking a row copies it and closes; Esc / click-off dismisses.

**`ScreenshotOverlay.qml`** — Fullscreen screenshot mode picker (`Print`): region, annotate, full, window, record, QR scan. Tiles dispatch through Hyprland IPC to `screenshot-launch.sh`, which closes the overlay, waits for the surface to clear, then runs `screenshot.sh` in the chosen mode.

**`KeybindCheatSheet.qml`** — Searchable keybind overlay (top-right, drops from Waybar). Reads `hyprctl binds -j` on first open, cached in-memory. Descriptions follow the "Section | Name" format set in `hyprland.lua`.

**`SliderRow.qml`** — Shared label + `Slider` + value display. `"%"` sliders carry a 0–1 fraction; other units (`K`, `ms`, `/s`) carry an absolute value with `from`/`to`.

## Settings panel

**`Settings.qml`** — Tabbed panel (top-right, drops from Waybar's ⚙ button, `Super+I`). Sidebar of tabs on the left, `StackLayout` of pages on the right. Waybar module clicks deep-link to a tab via `qs_manager.sh toggle settings <tab>`.

Tabs, in order: **Control · Wi-Fi · Bluetooth · KDE Connect · Audio · Monitors · Wallpaper · Theme · Keyboard · Input · Battery (laptops) · Drives · System · Nix**. Each page is a plain `Item` (no window chrome). A tab = one entry in `Settings.qml`'s `tabs` array **plus** the matching page in its `StackLayout` (same order); the id must also appear in `Shell.qml`'s `settingsTabs`. Tabs needing a pre-scan hook into `qs_manager.sh` `PREP_TAB`.

**`ControlCenter.qml`** — Quick toggles grid + sliders. Tiles: Wi-Fi (`nmcli`), Bluetooth (`bluetoothctl`), Night Light, Do Not Disturb, Power Profile cycle (`powerprofilesctl`), Caffeine (toggles `hypridle`), Airplane (both radios), Mic mute (PipeWire source), Game Mode (`hyprctl` blur/anim), and Tailscale (only when the CLI is present). Brightness + night-light Warmth sliders. Night light is a manual override over the gammastep service, tracked by a runtime flag file. Polls state on open. Also carries a **weather** readout (`wttr.in`, IP-located, no key, cached 30 min) and a **focus/Pomodoro timer** (25/5, start·pause·reset·skip) whose state lives in this page so it keeps running while the panel is closed and notifies on each phase change.

**`AudioMixer.qml`** — PipeWire audio page. Default sink/source volume + mute, output/input **device selectors** (sets the default via `preferredDefaultAudioSink/Source`), per-app stream volumes (`PwObjectTracker`), an **EasyEffects** equalizer section (enable toggle, preset chips, open-GUI button), and **per-app output routing** (sink chips per app via `pactl -f json` + `move-sink-input`; shown only with >1 sink).

**`SysInfoPanel.qml`** — System stats page. CPU usage + package temp, memory, root disk, and GPU (`nvidia-smi`; row hidden when absent), each a thin progress bar polled every 2s while open. A **Fans** list shows live RPMs (`sensors -u`; section hidden when no fan reads > 0). Header button opens `btop` in kitty.

**`NetworkPanel.qml`** — Wi-Fi page. Radio toggle, scanned network list (strongest AP per SSID, in-use first), click to connect/disconnect via `nmcli` — known networks connect directly, new secured ones get an inline password prompt; a failed connect deletes the half-made profile for clean retries. A **VPN / WireGuard** section lists NetworkManager `vpn`/`wireguard` connections with up/down toggles (hidden when none exist). `qs_manager.sh` kicks a hardware rescan on open (`PREP_TAB == network`); the list refreshes every 8s while visible.

**`KDEConnectPanel.qml`** — KDE Connect page. Lists devices via `kdeconnect-cli --list-devices` (parsed to id/name/paired/reachable), with pair/unpair and ring ("find my phone"). Needs `programs.kdeconnect.enable` (daemon + firewall 1714-1764, set in `productivity.nix`); the cli DBus-activates the daemon. Shows a hint when the cli is absent or no devices are paired.

**`BluetoothPanel.qml`** — Bluetooth page. Power toggle, device list via `bluetoothctl` (connect/disconnect, pair, remove), per-device battery %, and a best-effort codec/profile selector (`pactl set-card-profile` on the active bluez card). `qs_manager.sh` starts a scan on open (`PREP_TAB == bluetooth`) and tears it down on close.

**`KeyboardPanel.qml`** — Keyboard page. Layout switch (`hyprctl switchxkblayout`), key repeat rate + delay (`hyprctl keyword input:repeat_*`), and keyboard backlight via `brightnessctl` `kbd_backlight` (row hidden when absent). Runtime-only.

**`InputPanel.qml`** — Input page. Touchpad tap-to-click + natural scroll and pointer sensitivity via `hyprctl keyword input:*`. Runtime-only.

**`BatteryPanel.qml`** — Battery page (laptop hosts). Charge %, state, health and time-remaining via `upower`; Framework charge-limit threshold read/write (`charge_control_end_threshold`, made writable by a udev rule in `modules/nixos/base.nix`). Hides battery detail on machines with no battery.

**`DiskPanel.qml`** — Drives page. Lists hot-pluggable block devices (`lsblk -J`, filtered to removable/hotplug so internal disks never appear) and mounts / ejects them via `udisksctl` (polkit grants the active session access — no root). SMART health per fixed disk comes from `/run/smart/summary.json` (root oneshot timer in `productivity.nix`). Polls every 5s while open.

**`NixPanel.qml`** — Nix page. Radial ring shows `/nix` partition usage (`df`). Buttons trigger `nh os switch` or `nh home switch` and stream live output. Spinner state wired back to Shell's `rebuildRunning`, which surfaces as the pulsing `custom/rebuild` module in Waybar.

**`MonitorManager.qml`** — Display page. Visual scaled map of connected monitors; click to select, then pick resolution / refresh rate (parsed from `hyprctl monitors -j availableModes`) / scale — all applied via `hyprctl keyword monitor`. A **Brightness** section gives a per-display slider for external monitors over DDC/CI (`ddcutil`, VCP 0x10, debounced writes); hidden when no DDC display is found. Needs `hardware.i2c.enable` (set on home-desktop).

**`WallpaperPicker.qml`** — Wallpaper page. Displays thumbnails pre-generated by `qs_manager.sh` into `~/.cache/quickshell/wallpaper_picker/thumbs/`. Clicking sets wallpaper via `awww` or `mpvpaper`. A per-output selector (shown only with multiple monitors) targets one display via `awww --outputs` / `mpvpaper <output>`; a **Random** button applies a random wallpaper.

**`qs_manager.sh`** — Shell-side IPC router and daemon watchdog. Fast path: OSD triggers (volume/brightness keys spam these). Slow path: starts quickshell if not running, fires per-tab prep (Wi-Fi rescan, Bluetooth scan, wallpaper thumbnails), routes `open`/`toggle`/`close` commands to `quickshell ipc call`.

## Launching

```bash
# Auto-started on first panel toggle via qs_manager.sh zombie watchdog.
# Manual launch:
quickshell -p ~/.config/hypr/scripts/quickshell/Shell.qml

# Toggle the Settings panel on a given tab:
~/.config/hypr/scripts/qs_manager.sh toggle settings <tab>
# Tabs: control, network, bluetooth, kdeconnect, audio, monitors, wallpaper,
#       theme, keyboard, input, battery, disks, sysinfo, nix
# (A bare tab name as <name> also works — it maps to the matching Settings tab.)
# Standalone pop-ups: notifications, keybinds, clipboard, screenshot, power, overview
# OSD (volume/brightness) is automatic — trigger via: qs_manager.sh osd <volume|brightness>

# Close all panels:
~/.config/hypr/scripts/qs_manager.sh close
```

## IPC

`qs_manager.sh` routes to Shell via:
```
quickshell ipc call main handleCommand <action> <target> <subtarget>
```
Actions: `open`, `toggle`, `close`, `osd`.
