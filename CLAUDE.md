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
| `productivity.nix` | Hyprland, SDDM, PipeWire, syncthing, core desktop apps |
| `creative-apps.nix` | GIMP, Inkscape, Krita |
| `streaming-tools.nix` | OBS, Shotcut, RustDesk, gpu-screen-recorder |
| `google-chrome.nix` | Google Chrome |
| `comms.nix` | Slack, Discord, Zoom |
| `nvidia.nix` | NVIDIA driver (open, RTX 40-series) |
| `cuda.nix` | CUDA / cuDNN stack |
| `gaming.nix` | Steam, Gamemode, Gamescope, Mangohud, controllers |
| `wine.nix` | DXVK |
| `gaming-streaming.nix` | OBS + Moonlight for game streaming |
| `lanzaboote.nix` | Secure Boot — import only after `sbctl` key enrollment |
| `plymouth.nix` | Custom boot splash |

### Home Manager

- Wired as a NixOS module via `home-manager.nixosModules.home-manager`.
- `mkHost` passes `hmArgs` to `home-manager.extraSpecialArgs`. **Do not** add `extraSpecialArgs` inside a host's `default.nix` — this conflicts with `mkHost` and is a recurring footgun.
- Shared args (git name/email) live in `sharedHmArgs` in `flake.nix`; per-host args override via `sharedHmArgs // hmArgs`.
- `home/max/` is split into feature files: `default.nix` (entry), `git.nix`, `cli.nix`, `desktop.nix`, `packages.nix`.
- Setting `compositor = "none"` (`minimal` host) skips Hyprland and Waybar entirely via `mkIf`.

### Rebuild

```bash
nixup   # nh os switch /etc/nixos  (auto-detects host by hostname)
# or explicitly:
sudo nixos-rebuild switch --flake /etc/nixos#<host>
```

### Shell scripts

All `*.sh` linted with shellcheck. Use `bash`, `set -euo pipefail`, quote properly.

## Adding things

| Want to add… | Where |
|---|---|
| System-wide package (all desktop hosts) | `environment.systemPackages` in the relevant `hosts/common/optional/*.nix` |
| System-wide package (one host only) | `environment.systemPackages` in `hosts/<name>/default.nix` |
| New optional feature | New file in `hosts/common/optional/`, import in the hosts that need it |
| User package | `home.packages` in `home/max/packages.nix` |
| New HM feature | New file in `home/max/`, add to imports in `home/max/default.nix` |
| Plain-text dotfile | `config/<app>/...` + wire via `xdg.configFile` |
| Live-editable script | `config/hypr-scripts/` (symlinked into `~/.config/hypr/scripts/`) |
| Package not in nixpkgs | Add derivation to `pkgs/default.nix`, expose via `overlays/default.nix` |

## Security

- Never commit credentials — `github_pat`, `*.iso` are gitignored.
- `hosts/home-desktop/default.nix` ships `initialPassword = "123"` — change on first login or replace with `hashedPassword` before deploy.
- `sshKeys = [ ]` is empty by default; populate before using `deploy.sh`.
- Secure boot: add `../common/optional/lanzaboote.nix` to a host after running `sbctl create-keys` + `sbctl enroll-keys`.

## Theme

**Gruvbox Material Dark** across all apps — GTK, Qt/qt6ct, kitty, tmux, Starship, btop, Zed, Zathura, fuzzel, waybar, hyprland.
