# nix — NixOS Configuration

Declarative, reproducible NixOS workstations using **Nix Flakes** and **Home Manager**.

## Hosts

| Host | Profile | Compositor | Features |
|------|---------|------------|----------|
| `home-desktop` | Gaming workstation (i7-13700K, RTX 40-series) | Hyprland | full stack |
| `work-laptop`  | Dev laptop | Hyprland | dev + productivity + TLP |
| `minimal`      | Headless / server | — | base only |

## Structure

```
flake.nix                        # inputs, mkHost helper, devShells
hosts/
  home-desktop/                  # RTX 40-series gaming workstation
  work-laptop/                   # Dev laptop (TLP, powersave specialisation)
  minimal/                       # Headless base
  common/optional/               # Import-composition feature files
    productivity.nix             #   Hyprland, SDDM, PipeWire, Syncthing
    nvidia.nix                   #   NVIDIA open driver (RTX 40-series)
    gaming.nix                   #   Steam, Gamemode, Gamescope, controllers
    development.nix              #   Language runtimes, dev tools
    cloud-tools.nix              #   kubectl, helm, opentofu, cloud CLIs
    ...                          #   see CLAUDE.md for full table
modules/
  nixos/base.nix                 # Core system: packages, networking, fonts
  home/                          # Home Manager modules
    shell.nix                    #   Zsh, Starship, fzf, zoxide, tmux
    editor.nix                   #   Zed, nil LSP
    apps.nix                     #   Kitty, btop, mpv, Zathura, Yazi, fuzzel
    theme.nix                    #   Gruvbox Material — GTK, Qt, cursors
    wm/hyprland.nix              #   Hyprland + Waybar (compositor-gated)
home/max/                        # User config entry point + feature files
overlays/                        # Custom package overrides
pkgs/                            # Local derivations
```

## Rebuild

```bash
nixup              # nh os switch /etc/nixos  (auto-detects host by hostname)

# Or explicitly:
sudo nixos-rebuild switch --flake /etc/nixos#home-desktop
```

## First install

See [docs/guides/nix-install.md](docs/guides/nix-install.md) — uses nixos-anywhere for automated partitioning + install in one command.

## Adding things

See the table in `CLAUDE.md`. Short version:

| Want to add… | Where |
|---|---|
| System package (one host) | `environment.systemPackages` in `hosts/<name>/default.nix` |
| System package (all desktop hosts) | relevant `hosts/common/optional/*.nix` |
| New optional feature | New file in `hosts/common/optional/`, import in the hosts that need it |
| User package | `home.packages` in `home/max/packages.nix` |

## Theme

**Gruvbox Material Dark** throughout — Hyprland, Waybar, Kitty, tmux, Starship, btop, Zed, Zathura, GTK, Qt.

## License

[MIT](LICENSE)
