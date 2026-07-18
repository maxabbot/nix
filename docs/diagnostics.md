# Diagnostics

## Boot

```bash
# Which boots are in the journal
journalctl --list-boots

# Emergency / activation failures in current boot
journalctl -b | grep -i "emergency\|failed to start\|activation" | head -40

# Full initrd activation log
journalctl -b 0 -u nixos-activation | tail -40
journalctl -b 0 -u initrd-nixos-activation | tail -40

# Previous boot (useful after a bad reboot)
journalctl -b -1 | grep -i "failed\|error\|emergency" | tail -40
```

## Hyprland session

```bash
# Find the active socket (v0.40+ uses XDG_RUNTIME_DIR, not /tmp)
ls /run/user/$(id -u)/hypr/

# Run hyprctl over SSH
HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/$(id -u)/hypr/ | tail -1) hyprctl monitors
HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/$(id -u)/hypr/ | tail -1) hyprctl clients
HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/$(id -u)/hypr/ | tail -1) hyprctl workspaces

# Monitor layout — run from inside Hyprland session
hyprctl monitors

# Cursor position — useful for diagnosing movement limits
hyprctl cursorpos
```

## Monitors (without a running compositor)

```bash
# Connected outputs and their status
cat /sys/class/drm/card*/status

# Available modes per connector
cat /sys/class/drm/card1-DP-2/modes | head -5
cat /sys/class/drm/card1-DP-3/modes | head -5
```

## SDDM

```bash
# Check if our kwinoutputconfig.json was written
sudo cat /var/lib/sddm/.config/kwinoutputconfig.json

# What files SDDM's KWin has written
sudo ls -la /var/lib/sddm/.config/
sudo ls -la /var/lib/sddm/.local/share/ 2>/dev/null

# SDDM service status and logs
# NB: the unit is `display-manager.service`, NOT `sddm.service`.
# `sddm` matches nothing — see the greeter-cursor note below for why that matters.
systemctl status display-manager
journalctl -b -u display-manager | tail -40

# Restart SDDM (returns to login screen — kills current session)
sudo systemctl restart display-manager
```

### Greeter cursor is invisible (KWin compositor)

Symptom in the journal (search the whole boot, not just the unit — KWin logs
under the `sddm-helper-start-wayland` identifier):

```bash
journalctl -b | grep -iE "kwin|cursor"
# kwin_core: Failed to load cursor theme "breeze_cursors"
# kwin_core: Unable to load any cursor theme
```

Root cause: SDDM starts the greeter session — **including the `kwin_wayland`
compositor that draws the pointer** — via `sddm-helper`, which **resets the
environment** and injects only what's in sddm.conf's `[General]
GreeterEnvironment`. So NONE of these reach KWin: the `display-manager.service`
systemd env, `sddm.extraPackages` (that only wires the greeter *binary's*
wrapper), or a `sddm.service` (which doesn't exist). With no `XCURSOR_PATH` on
the greeter env KWin can't find `breeze_cursors`, draws no cursor at all, and
`KWIN_FORCE_SW_CURSOR` can't help (no image to draw).

Fix (in `hosts/common/optional/productivity.nix`): put the cursor vars into
`displayManager.sddm.settings.General.GreeterEnvironment`. silentSDDM's module
hardcodes that string (QML2_IMPORT_PATH + QT_IM_MODULE), so override with
`lib.mkForce`, re-adding those two and appending `XCURSOR_PATH`/`XCURSOR_THEME`/
`XCURSOR_SIZE`/`KWIN_FORCE_SW_CURSOR`. `kcminputrc` (via the `sddmCursorConfig`
activation script) supplies the theme NAME; GreeterEnvironment supplies the PATH.

```bash
# Confirm the cursor vars are in the generated greeter env
grep GreeterEnvironment /etc/sddm.conf.d/00-nixos.conf
# After a greeter restart, the "Unable to load any cursor theme" lines should be gone.
```

## Services

```bash
# Failed units in current boot
systemctl --failed

# Logs for a specific unit
journalctl -b -u xdg-desktop-portal-hyprland.service | tail -20
journalctl -b -u gammastep.service | tail -20

# User-level failed units (run as max, not root)
systemctl --user --failed
journalctl --user -b | grep -i failed | tail -20
```

## NixOS rebuild

```bash
# Standard rebuild — shows diff before applying
nixup   # alias for: nh os switch /etc/nixos

# Or raw (any host)
sudo nixos-rebuild switch --flake /etc/nixos#home-desktop

# Dry run (check for eval errors without building)
sudo nixos-rebuild dry-activate --flake /etc/nixos#home-desktop

# Show what will change without applying
nh os switch /etc/nixos --dry
```
