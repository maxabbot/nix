# CLAUDE.md

## Project Overview

NixOS workstation configuration using **Nix Flakes** and **Home Manager**. Declarative, reproducible, fully idempotent.

Three hosts: `home-desktop` (RTX 40-series, Hyprland, gaming), `work-laptop` (Hyprland, TLP, no GPU), `minimal` (headless, no compositor).

## Key Conventions

### Module system

- Each module exposes options under `custom.<name>.*`, all **off by default**.
- Hosts in `hosts/<name>/default.nix` import modules and enable what they need.
- The `hyprland` flake input's `nixosModules.default` is only loaded on desktop hosts — not in `mkHost` — so `minimal` stays GUI-free.

### Option hierarchy

```
custom.base.{enable, username, timezone, powerManagement, firewall, hashedPassword, initialPassword, sshKeys, fancontrol.*}
custom.plymouth.enable
custom.development.{enable, containers.podman.enable, containers.libvirt.enable, database.*, cloudTools.enable}
custom.productivity.{enable, creativeApps.enable, streamingTools.enable, secondaryBrowsers.enable, communicationApps.enable}
custom.nvidia.{enable, open, cuda.enable}
custom.gaming.{enable, wineExtras.enable, streaming.enable, extraGpuVendors.enable}
```

`custom.productivity` hard-codes Hyprland — Sway is not supported.

### Home Manager

- Wired as a NixOS module via `home-manager.nixosModules.home-manager`.
- `mkHost` passes `hmArgs` to `home-manager.extraSpecialArgs`. **Do not** add `extraSpecialArgs` inside a host's `default.nix` — this conflicts with `mkHost` and is a recurring footgun.
- `home/max/default.nix` receives: `machineType`, `compositor`, `monitors`, `git`, `location`, `inputs`.
- Setting `compositor = "none"` (`minimal` host) skips Hyprland and Waybar entirely via `mkIf`.

### Rebuild

```bash
./setup.sh        # auto-detects hostname
# or explicitly:
sudo nixos-rebuild switch --flake /etc/nixos#<host>
```

### Shell scripts

All `*.sh` linted with shellcheck. Use `bash`, `set -euo pipefail`, quote properly.

## Adding things

| Want to add… | Where |
|---|---|
| System-wide package | `environment.systemPackages` in `modules/nixos/<role>.nix` |
| User package | `home.packages` in `home/max/default.nix` or `modules/home/<x>.nix` |
| Optional package gate | New `mkEnableOption` in the module, enable in the host |
| Plain-text dotfile | `config/<app>/...` + wire via `xdg.configFile` |
| Live-editable script | `config/hypr-scripts/` (symlinked into `~/.config/hypr/scripts/`) |
| Package not in nixpkgs | Add derivation to `pkgs/default.nix`, expose via `overlays/default.nix` |
| New NixOS module | `modules/nixos/<name>.nix` with `options.custom.<name>.*` + `config = lib.mkIf cfg.enable { ... }`, import in host |

## Security

- Never commit credentials — `github_pat`, `*.iso` are gitignored.
- `hosts/home-desktop/default.nix` ships `initialPassword = "123"` — change on first login or replace with `hashedPassword` before deploy.
- `sshKeys = [ ]` is empty by default; populate before using `deploy.sh`.

## Theme

**Gruvbox Material Dark** across all apps — GTK, Qt/qt6ct, kitty, tmux, Starship, btop, Zed, Zathura, fuzzel, waybar, hyprland.
