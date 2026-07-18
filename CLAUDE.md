# CLAUDE.md

## Project Overview

NixOS workstation configuration using **Nix Flakes** and **Home Manager**. Declarative, reproducible, fully idempotent.

Four hosts: `home-desktop` (RTX 40-series, Hyprland, gaming), `work-laptop` (Hyprland, TLP, no GPU), `vm` (home-desktop stack in a QEMU/virtio VM — no NVIDIA/CUDA/fancontrol), `minimal` (headless, no compositor).

## Key Conventions

### Module system

Two patterns in use:

1. **Option-flag modules** (`modules/nixos/`) — only `base.nix` remains here. Exposes `custom.base.*` options; hosts set these to configure timezone, username, power management, etc.

2. **Import composition** (`hosts/common/optional/`) — pure config files, no options. Hosts simply import the ones they need. Each file is self-contained: it declares packages, services, and options directly.

The `hyprland` nixos module and HM shared module are loaded inside `hosts/common/optional/productivity.nix`, so `minimal` (which doesn't import it) stays GUI-free.

### Option hierarchy (base module only)

```
custom.base.{enable, username, timezone, powerManagement, firewall, hashedPassword, initialPassword, sshKeys, fancontrol.*}
```

### hosts/common/optional/ files

| File | Purpose |
|---|---|
| `development.nix` | Language runtimes, dev tools, openssh, direnv |
| `podman.nix` | Podman + Docker compat |
| `libvirt.nix` | libvirt / QEMU-KVM |
| `db-gui.nix` | DBeaver, Beekeeper, mycli, litecli |
| `duckdb.nix` | DuckDB |
| `cloud-tools.nix` | kubectl, helm, opentofu, AWS/Azure/GCP CLIs |
| `productivity.nix` | Hyprland, SDDM (SilentSDDM), PipeWire, syncthing, core desktop apps |
| `stylix.nix` | Stylix theming (base16 Gruvbox Material, fonts, cursor) |
| `creative-apps.nix` | GIMP, Inkscape, Krita |
| `streaming-tools.nix` | OBS, Shotcut, RustDesk, gpu-screen-recorder |
| `google-chrome.nix` | Google Chrome |
| `comms.nix` | Slack, Discord, Zoom |
| `nvidia.nix` | NVIDIA driver (open, RTX 40-series) |
| `cuda.nix` | CUDA / cuDNN stack |
| `gaming.nix` | Steam, Gamemode, Gamescope, Mangohud, controllers |
| `wine.nix` | Wine (WoW64 staging), winetricks, DXVK |
| `gaming-streaming.nix` | Apollo (Sunshine fork) + Moonlight for game streaming |
| `fan2go.nix` | Moving-average fan control (home-desktop; replaces fancontrol) |
| `lan-mouse.nix` | Software KVM firewall port (config in `home/max/lan-mouse.nix` + `lanMouse` hmArgs) |
| `lanzaboote.nix` | Secure Boot — import only after `sbctl` key enrollment |
| `plymouth.nix` | Custom boot splash |

### Home Manager

- Wired as a NixOS module via `home-manager.nixosModules.home-manager`.
- `mkHost` passes `hmArgs` to `home-manager.extraSpecialArgs`. **Do not** add `extraSpecialArgs` inside a host's `default.nix` — this conflicts with `mkHost` and is a recurring footgun.
- Shared args (git name/email) live in `sharedHmArgs` in `flake.nix`; per-host args override via `sharedHmArgs // hmArgs`.
- `home/max/` is split into feature files: `default.nix` (entry), `git.nix`, `cli.nix`, `desktop.nix`, `packages.nix`, `terminal-toys.nix`.
- Setting `compositor = "none"` (`minimal` host) skips Hyprland and Waybar entirely via `mkIf`.

### Rebuild

```bash
nixup   # nh os switch /etc/nixos  (auto-detects host by hostname)
# or explicitly:
sudo nixos-rebuild switch --flake /etc/nixos#<host>
```

### Shell scripts

All `*.sh` linted with shellcheck; quote properly. Use `bash` and prefer `set -euo pipefail` for new scripts (long-running event loops in `config/hypr-scripts/` intentionally omit it so one failed poll doesn't kill the loop).

## Adding things

| Want to add… | Where |
|---|---|
| System-wide package (all desktop hosts) | `environment.systemPackages` in the relevant `hosts/common/optional/*.nix` |
| System-wide package (one host only) | `environment.systemPackages` in `hosts/<name>/default.nix` |
| New optional feature | New file in `hosts/common/optional/`, import in the hosts that need it |
| User package | `home.packages` in `home/max/packages.nix` |
| New HM feature | New file in `home/max/`, add to imports in `home/max/default.nix` |
| Plain-text dotfile | `config/<app>/...` + wire via `xdg.configFile` |
| Hypr/Quickshell script or QML | `config/hypr-scripts/` — deployed as a store symlink to `~/.config/hypr/scripts/`, so edits need `git add` + `nixup` (+ quickshell restart for QML) to take effect |
| Package not in nixpkgs | Add derivation under `pkgs/<name>/`, expose via `callPackage` in `overlays/default.nix` |

## Security

- Never commit credentials — `github_pat`, `*.iso` are gitignored.
- Hosts currently set `custom.base.hashedPassword` inline — the hash is in git history, so treat it as exposed: move to agenix/sops-nix (`hashedPasswordFile`) and rotate the password (see TODO.md).
- `sshKeys = [ ]` is empty by default; populate before enabling `services.openssh` for remote login.
- Secure boot: add `../common/optional/lanzaboote.nix` to a host after running `sbctl create-keys` + `sbctl enroll-keys`.

## Theme

**Gruvbox Material Dark** across all apps. `config/stylix/palette.nix` is the single source of truth for colour values: Stylix (`hosts/common/optional/stylix.nix`) derives its base16 scheme from it and owns GTK/Qt/fonts/cursor; apps with richer needs (kitty, tmux, Starship, waybar, cava, spotify-player) have their Stylix targets disabled and interpolate the palette in their Nix modules instead. Plain-text configs that can't interpolate Nix (`config/hypr-scripts/quickshell/Theme.qml`, `hyprlock.conf`, `shortcuts.css`, `hyprland.lua`, fastfetch) still carry hand-maintained copies — keep them in sync when changing a colour.
