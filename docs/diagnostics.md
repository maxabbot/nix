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

## Greeter (DMS on greetd)

```bash
# greetd status and logs — the unit is greetd.service (aliased display-manager)
systemctl status greetd
journalctl -b -u greetd | tail -40

# The greeter's Hyprland and quickshell log under their own identifier
journalctl -b -t dms-greeter/hyprland | tail -40

# What greetd copied in before the greeter started (settings, theme, wallpaper)
sudo ls -la /var/lib/dms-greeter/

# Restart the greeter (returns to login screen — kills current session)
sudo systemctl restart greetd
```

### Login hangs after the password is accepted

greetd starts the session only once the greeter has exited. The launcher stops
its Hyprland with `hyprctl dispatch exit`, which Hyprland on Lua rejects, so
`productivity.nix` patches that call to `hl.dsp.exit()` (the `dmsGreeter`
override). After a dms-shell bump, check the substitution still applies — it is
`--replace-fail`, so a reworded launcher fails the build rather than the login.

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
