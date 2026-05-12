# CLAUDE.md

## Project Overview

NixOS workstation configuration using **Nix Flakes** and **Home Manager**.
Declarative, reproducible, and fully idempotent.

## Repository Structure

```
flake.nix                  # Inputs (nixpkgs unstable, home-manager, disko, zen-browser, hyprland) + nixosConfigurations
flake.lock                 # Pinned input revisions
setup.sh                   # On-host rebuild wrapper (auto-detects hostname)
deploy.sh                  # Remote install wrapper around nixos-anywhere (over SSH, with disk-config gate)
hosts/
  home-desktop/            # Desktop workstation — RTX 40-series, Hyprland, gaming, full dev
    default.nix            #   Sets custom.* options
    disk-config.nix        #   disko layout (NVMe → ESP + Btrfs subvolumes)
    hardware-configuration.nix
  work-laptop/             # Dev laptop — Hyprland, TLP, no GPU/gaming
    default.nix
    disk-config.nix
    hardware-configuration.nix
  minimal/                 # Headless / base only — no compositor, no HM GUI modules
    default.nix
    hardware-configuration.nix
modules/
  nixos/                   # System-level NixOS modules
    base.nix               #   Core: kernel, networking, fonts, packages, user, GC, plymouth
    development.nix        #   Languages, containers, cloud CLIs, DB tools, openssh
    productivity.nix       #   Hyprland, SDDM, PipeWire, Wayland tools, apps, syncthing, flatpak
    nvidia.nix             #   Drivers, CUDA, kernel params, Wayland env, persistenced
    gaming.nix             #   Steam, Wine, Proton, gamemode, gamescope, xpadneo
  home/                    # Home Manager modules
    default.nix            #   Imports shell, editor, apps, theme, wm/hyprland, wm/waybar
    shell.nix              #   Zsh + history, Starship, fzf, zoxide, tmux, aliases/functions
    editor.nix             #   Zed (primary) + VSCode (backup)
    apps.nix               #   Kitty, btop, mpv, Zathura, Fuzzel, swayosd, swaync, wlogout, fastfetch, mise, tmux-sessionizer
    theme.nix              #   Gruvbox Material — GTK, Qt/qt6ct, cursor, mime defaults, matugen
    wm/
      hyprland.nix         #   Hyprland config (parameterised by monitors)
      waybar.nix           #   Waybar (Hyprland workspaces module)
home/
  max/default.nix          # HM user config — git, ssh, bat, eza, rg, gammastep, direnv, zsh wiring
config/                    # Plain-text dotfiles consumed by HM via xdg.configFile and symlinks
  cava/                    #   cava base config (merged with matugen colors at launch)
  fastfetch/               #   fastfetch config.jsonc
  hypr/                    #   hyprlock.conf
  hypr-scripts/            #   Live-symlinked into ~/.config/hypr/scripts/ — quickshell, gaming-toggle, etc.
  matugen/                 #   matugen config + templates (Gruvbox Material dynamic theming)
  mise/                    #   mise config.toml
  plymouth/simple/         #   Plymouth boot splash assets
  scripts/                 #   tmux-sessionizer (wrapped via writeShellScriptBin)
  swaync/                  #   notification daemon config + style
  wlogout/                 #   logout screen layout + style
overlays/default.nix       # Custom package overrides (currently empty stub)
pkgs/default.nix           # Local derivations not in nixpkgs (currently empty stub)
docs/                      # Installation, post-install, shortcuts, diagnostics
.github/workflows/ci.yml   # nix flake check, nixfmt-rfc-style, shellcheck
```

## Key Conventions

### NixOS Modules

- Each module exposes options under `custom.<name>.*`.
- All options are **off by default** — hosts explicitly enable what they need.
- Host configs in `hosts/<name>/default.nix` import the relevant modules and set options.
- `hardware-configuration.nix` is host-specific; replace with `sudo nixos-generate-config --root /mnt` output on each target.
- The `hyprland` flake input's `nixosModules.default` is loaded **only** on desktop hosts (`home-desktop`, `work-laptop`) via the host's `modules` list — not in `mkHost` itself, so `minimal` stays GUI-free.

### Module option hierarchy

```nix
custom.base.{enable, username, timezone, powerManagement, firewall,
             hashedPassword, initialPassword, sshKeys, plymouth.enable}
custom.development.{enable, containers.podman.enable, containers.libvirt.enable,
                    database.guiClients.enable, database.dataPlatforms.enable, cloudTools.enable}
custom.productivity.{enable, creativeApps.enable, streamingTools.enable,
                     secondaryBrowsers.enable, communicationApps.enable}
custom.nvidia.{enable, open, cuda.enable}
custom.gaming.{enable, wineExtras.enable, streaming.enable, apollo.enable, extraGpuVendors.enable}
```

`custom.productivity` hard-codes Hyprland as the compositor — Sway is not supported.

### Home Manager

- HM is wired as a NixOS module via `home-manager.nixosModules.home-manager`.
- `mkHost` passes `hmArgs` to `home-manager.extraSpecialArgs`; each host owns its own args
  (machineType, compositor, monitors, location, git). **Do not** duplicate `extraSpecialArgs`
  inside a host's `default.nix` — that conflicts with `mkHost` and is a recurring footgun.
- `home/max/default.nix` receives `specialArgs`: `machineType`, `compositor`, `monitors`, `git`, `location`, `inputs`.
- Compositor-specific options live under `custom.hm.{compositor, monitors.*}` (defined in `modules/home/wm/hyprland.nix`).
- Setting `compositor = "none"` (the `minimal` host) skips Hyprland and Waybar entirely via `mkIf`.

### Running a rebuild

```bash
sudo nixos-rebuild switch --flake /etc/nixos#home-desktop
sudo nixos-rebuild switch --flake /etc/nixos#work-laptop
sudo nixos-rebuild switch --flake /etc/nixos#minimal
```

Or just `./setup.sh` on the target host (auto-detects via `hostname -s`).

### Shell scripts

- All `*.sh` are linted with **shellcheck** in CI. Config: `.shellcheckrc` enables `external-sources=true`.
- Use `bash`, `set -euo pipefail`, and quote properly.

## CI/CD

GitHub Actions (`.github/workflows/ci.yml`):
- `nix flake check --no-build` — evaluates all `nixosConfigurations`
- `nixfmt-rfc-style` — formatting check across `flake.nix`, `modules/`, `hosts/`, `home/`, `overlays/`, `pkgs/`
- `shellcheck` — lints every tracked `*.sh`

## Adding things

| Want to add… | Where |
|---|---|
| System-wide package | `environment.systemPackages` in the relevant `modules/nixos/<role>.nix` |
| User package | `home.packages` in `home/max/default.nix` or the relevant `modules/home/<x>.nix` |
| Optional package gate | New `mkEnableOption` in the module, then enable in the host |
| Plain-text dotfile | `config/<app>/...` + wire via `xdg.configFile."<app>/..."source = ../../config/<app>/...;` |
| Live-editable script | `config/hypr-scripts/` (symlinked into `~/.config/hypr/scripts/` for Hyprland) |
| Package not in nixpkgs | Add derivation to `pkgs/default.nix`, expose via `overlays/default.nix` |
| New NixOS module | `modules/nixos/<name>.nix` with `options.custom.<name>.*` and `config = lib.mkIf cfg.enable { ... }`, then import + enable in the host |

## Security

- Never commit credentials — `github_pat`, `*.iso` are gitignored.
- `result` / `result-*` (Nix build outputs) are gitignored.
- `hosts/home-desktop/default.nix` ships `initialPassword = "123"` — **must** be changed
  on first login, or replaced with `hashedPassword` before deploy.
- `sshKeys = [ ]` is empty by default; populate before relying on `deploy.sh`.

## Theme

**Gruvbox Material Dark** across GTK, Qt/Kvantum, btop, kitty, tmux, Starship, Zathura, mpv,
fzf, fuzzel, waybar, hyprland. Matugen generates dynamic per-wallpaper variants at runtime
into `~/.cache/matugen/` and `~/.config/{kitty,swayosd,...}` — initial empty fallbacks are
created by activation scripts so the first boot doesn't fail on missing imports.

Palette: `#282828` bg · `#d4be98` fg · `#7daea3` blue · `#d8a657` yellow · `#ea6962` red · `#a9b665` green · `#d3869b` purple
