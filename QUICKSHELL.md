# Quickshell

Bottom bar + panel system replacing Waybar and swaync. Entry point: `config/hypr-scripts/quickshell/Shell.qml`. Managed by `config/hypr-scripts/qs_manager.sh`.

## Components

**`Theme.qml`** — `pragma Singleton` holding the Gruvbox Material Dark palette, the UI font (`JetBrainsMono Nerd Font`), and shared metrics. Every component references colours/fonts as `Theme.<token>` (e.g. `Theme.bg`, `Theme.accent`, `Theme.font`) — no `import` needed, it resolves by same-directory registration. Change a colour here once and it updates across the whole shell.

**`Shell.qml`** — Entry point. Owns all global state (`activePanel`, `dndEnabled`, `rebuildRunning`), the `IpcHandler` for `qs_manager.sh` commands, the `NotificationServer` (D-Bus `org.freedesktop.Notifications`), the transient toast window, and spawns one `Bar` per screen via `Variants`.

**`Bar.qml`** — Bottom bar content (40px, full-width per screen). Left: workspace dots. Centre: media player. Right: keybinds, rebuild spinner, nix, monitors, wallpaper, notifications, control center, audio buttons. Emits `panelToggled(name)` up to Shell. (Power actions: `Super+Shift+E` → wlogout.) (App launching and clipboard history are handled by fuzzel — see `modules/home/apps.nix` and `config/hypr-scripts/clipboard-fuzzel.sh`.)

**`BarButton.qml`** — Shared icon button used by Bar. Supports `active` highlight, `badge` count, and tooltip.

**`Workspaces.qml`** — Clickable workspace dots in the bar. Reads `Hyprland.workspaces`, highlights the focused one, switches via `modelData.activate()`.

**`MediaPlayer.qml`** — Centre bar widget showing current MPRIS track (title + artist), prev/play/next controls. Visible only when a player is active.

**`NotificationCenter.qml`** — Scrollable notification history (bottom-right, 390×500). Shows all current notifications with dismiss and clear-all. Fed the `NotificationServer`'s model from Shell.

**`NotificationToast.qml`** — Transient top-right toast for incoming notifications. Used in the repeater inside Shell's toast `PanelWindow`.

### Settings tabs (pages of `Settings.qml`)

The tabbed `Settings` panel hosts these pages, in order: **Control · Wi-Fi · Bluetooth · Audio · Monitors · Wallpaper · Theme · Keyboard · Input · Battery · System · Nix**. Each is a plain `Item` (no window chrome). A tab = one entry in `Settings.qml`'s `tabs` array **plus** the matching page in its `StackLayout` (same order); the id must also appear in `Shell.qml`'s `settingsTabs`. Tabs needing a pre-scan hook into `qs_manager.sh` `PREP_TAB`.

**`ControlCenter.qml`** — Quick toggles grid + sliders. Tiles: Wi-Fi (`nmcli`), Bluetooth (`bluetoothctl`), Night Light, Do Not Disturb, Power Profile cycle (`powerprofilesctl`), Caffeine (toggles `hypridle`), Airplane (both radios), Mic mute (PipeWire source), Game Mode (`hyprctl` blur/anim), and Tailscale (only when the CLI is present). Brightness + night-light Warmth sliders. Night light is a manual override over the gammastep service, tracked by a runtime flag file. Polls state on open.

**`AudioMixer.qml`** — PipeWire audio page. Default sink/source volume + mute, output/input **device selectors** (sets the default via `preferredDefaultAudioSink/Source`), per-app stream volumes (`PwObjectTracker`), and an **EasyEffects** equalizer section (enable toggle, preset chips, open-GUI button).

**`SysInfoPanel.qml`** — System stats page. CPU usage + package temp, memory, root disk, and GPU (`nvidia-smi`; row hidden when absent), each a thin progress bar polled every 2s while open. Header button opens `btop` in kitty.

**`NetworkPanel.qml`** — Wi-Fi page. Radio toggle, scanned network list (strongest AP per SSID, in-use first), click to connect/disconnect via `nmcli` — known networks connect directly, new secured ones get an inline password prompt; a failed connect deletes the half-made profile for clean retries. `qs_manager.sh` kicks a hardware rescan on open (`PREP_TAB == network`); the list refreshes every 8s while visible.

**`BluetoothPanel.qml`** — Bluetooth page. Power toggle, device list via `bluetoothctl` (connect/disconnect, pair, remove), per-device battery %, and a best-effort codec/profile selector (`pactl set-card-profile` on the active bluez card). `qs_manager.sh` starts a scan on open (`PREP_TAB == bluetooth`) and tears it down on close.

**`ThemePanel.qml`** — Theme page. Drives the optional palette override `Theme.qml` reads (`~/.cache/quickshell/palette.json`): accent swatches, or **matugen** "generate from wallpaper" (maps Material roles → palette tokens), or reset to Gruvbox. Calls `Theme.reloadPalette()` after each write so changes apply live.

**`KeyboardPanel.qml`** — Keyboard page. Layout switch (`hyprctl switchxkblayout`), key repeat rate + delay (`hyprctl keyword input:repeat_*`), and keyboard backlight via `brightnessctl` `kbd_backlight` (row hidden when absent). Runtime-only.

**`InputPanel.qml`** — Input page. Touchpad tap-to-click + natural scroll and pointer sensitivity via `hyprctl keyword input:*`. Runtime-only.

**`BatteryPanel.qml`** — Battery page. Charge %, state, health and time-remaining via `upower`; Framework charge-limit threshold read/write (`charge_control_end_threshold`, made writable by a udev rule in `modules/nixos/base.nix`). Hides battery detail on machines with no battery.

**`SliderRow.qml`** — Shared label + `Slider` + value display. `"%"` sliders carry a 0–1 fraction; other units (`K`, `ms`, `/s`) carry an absolute value with `from`/`to`.

**`KeybindCheatSheet.qml`** — Searchable keybind overlay (bottom-right, 480×560). Reads `hyprctl binds -j` on first open, cached in-memory.

**`NixPanel.qml`** — Nix store gauge + live rebuild tracker (bottom-right, 480×660). Radial ring shows `/nix` partition usage (`df`). Buttons trigger `nh os switch` or `nh home switch` and stream live output. Spinner state wired back to Shell's `rebuildRunning`.

**`MonitorManager.qml`** — Display page. Visual scaled map of connected monitors; click to select, then pick resolution / refresh rate (parsed from `hyprctl monitors -j availableModes`) / scale — all applied via `hyprctl keyword monitor`.

**`WallpaperPicker.qml`** — Wallpaper browser (full-width bottom, 460px). Displays thumbnails pre-generated by `qs_manager.sh` into `~/.cache/quickshell/wallpaper_picker/thumbs/`. Clicking sets wallpaper via `awww` or `mpvpaper`.

**`qs_manager.sh`** — Shell-side IPC router and daemon watchdog. Fast path: workspace switching (bypasses all caching). Slow path: starts quickshell if not running, pre-generates caches (network scan, wallpaper thumbnails), routes `open`/`toggle`/`close` commands to `quickshell ipc call`.

## Launching

```bash
# Auto-started on first panel toggle via qs_manager.sh zombie watchdog.
# Manual launch:
quickshell -p ~/.config/hypr/scripts/quickshell/Shell.qml

# Toggle the Settings panel on a given tab:
~/.config/hypr/scripts/qs_manager.sh toggle settings <tab>
# Tabs: control, network, bluetooth, audio, monitors, wallpaper, theme,
#       keyboard, input, battery, sysinfo, nix
# (A bare tab name as <name> also works — it maps to the matching Settings tab.)
# Standalone pop-ups: notifications, keybinds, clipboard, screenshot

# Close all panels:
~/.config/hypr/scripts/qs_manager.sh close
```

## IPC

`qs_manager.sh` routes to Shell via:
```
quickshell ipc call main handleCommand <action> <target> <subtarget>
```
Actions: `open`, `toggle`, `close`.
