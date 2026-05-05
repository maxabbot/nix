# nix — NixOS Configuration

Infrastructure-as-Code for NixOS workstations using **Nix Flakes** and **Home Manager**.

## Architecture

```text
flake.nix                    # Entry point — inputs, nixosConfigurations
hosts/
  home-desktop/              # Gaming workstation (RTX 40-series, Hyprland)
  work-laptop/               # Dev laptop (Sway, TLP)
  minimal/                   # Headless / base only
modules/
  nixos/                     # System-level NixOS modules
    base.nix                 #   Core packages, networking, fonts
    development.nix          #   Languages, containers, cloud CLIs
    productivity.nix         #   DE, audio, browsers, apps
    nvidia.nix               #   Drivers, CUDA, kernel params
    gaming.nix               #   Steam, Wine, Proton, controllers
  home/                      # Home Manager modules
    shell.nix                #   Zsh, Starship, aliases, tmux
    editor.nix               #   Helix, Neovim, Zed
    apps.nix                 #   Kitty, btop, mpv, Zathura, Yazi
    theme.nix                #   Gruvbox Material — GTK, Qt, cursors
    wm/
      hyprland.nix           #   Hyprland config
      sway.nix               #   Sway config
home/
  max/default.nix            # Home Manager user config
overlays/default.nix         # Custom package overrides
pkgs/default.nix             # Local derivations
```

## Quick start

### Rebuild an existing NixOS system

```bash
git clone https://github.com/maxabbot/nix.git /etc/nixos
cd /etc/nixos
sudo nixos-rebuild switch --flake .#home-desktop   # or work-laptop / minimal
```

Or use the wrapper script (auto-detects hostname):

```bash
./setup.sh
```

### First-time NixOS installation

1. Boot the NixOS ISO
2. Partition and mount disks (see [docs/post-installation.md](docs/post-installation.md))
3. Generate hardware config:
   ```bash
   sudo nixos-generate-config --root /mnt
   cp /mnt/etc/nixos/hardware-configuration.nix hosts/<hostname>/hardware-configuration.nix
   ```
4. Install:
   ```bash
   sudo nixos-install --flake github:maxabbot/nix#home-desktop
   ```

## Hosts

| Host | Profile | Compositor | Features |
|------|---------|------------|----------|
| `home-desktop` | Gaming workstation | Hyprland | base + dev + productivity + nvidia + gaming |
| `work-laptop`  | Dev laptop          | Sway      | base + dev + productivity + TLP |
| `minimal`      | Headless / server   | —         | base only |

## Modules

### NixOS system modules

| Module | Key options |
|--------|-------------|
| `custom.base` | `username`, `timezone`, `btrfsSnapshots`, `powerManagement`, `firewall` |
| `custom.development` | `containers.podman`, `containers.libvirt`, `database.*`, `cloudTools` |
| `custom.productivity` | `compositor`, `creativeApps`, `streamingTools`, `communicationApps` |
| `custom.nvidia` | `open`, `cuda` |
| `custom.gaming` | `wineExtras`, `streaming`, `apollo` |

### Home Manager modules

- **shell.nix** — Zsh with autosuggestions, syntax highlighting, history search; Starship (Gruvbox Material), fzf, zoxide, tmux, NixOS-native aliases replacing pacman/yay
- **editor.nix** — Helix (primary, with LSPs), Neovim (lazy.nvim), Zed
- **apps.nix** — Kitty, btop, mpv, Zathura, Yazi (all Gruvbox Material themed)
- **theme.nix** — GTK (Gruvbox-Material-Dark), Kvantum, Papirus icons, Bibata cursor
- **wm/hyprland.nix** — Full Hyprland config, gaming optimizations, multi-monitor via `custom.hm.monitors`
- **wm/sway.nix** — Full Sway config

## Customising

### Update git identity

Edit `home-manager.extraSpecialArgs.git` in the relevant `hosts/<name>/default.nix`.

### Change monitor configuration

Edit `monitors.primary` / `monitors.secondary` in the host's `extraSpecialArgs`:

```nix
monitors = {
  primary   = "DP-1,2560x1440@144,0x0,1";
  secondary = "HDMI-A-1,1920x1080@60,2560x0,1";
};
```

### Add packages

- **System packages** → `modules/nixos/<role>.nix` → `environment.systemPackages`
- **User packages** → `home/max/default.nix` → `home.packages`
- **Shell tools** → `modules/home/shell.nix`

### Enable optional features

```nix
custom.productivity.creativeApps.enable    = true;  # GIMP, Inkscape, Krita
custom.gaming.streaming.enable             = true;  # OBS, Moonlight
custom.development.database.servers.enable = true;  # PostgreSQL, Redis, MariaDB
custom.nvidia.cuda.enable                  = true;  # CUDA / cuDNN
```

## Useful commands

```bash
# Rebuild (fast, same generation)
sudo nixos-rebuild switch --flake .#home-desktop

# Test without switching the boot default
sudo nixos-rebuild test --flake .#home-desktop

# Update all flake inputs
nix flake update

# Search packages
nix search nixpkgs <name>

# Garbage collect old generations
sudo nix-collect-garbage -d
sudo nix store optimise

# Show system generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

## Theme

**Gruvbox Material Dark** throughout — kitty, tmux, Starship, btop, Helix, Zathura, GTK, Qt/Kvantum.  
Palette: `#282828` bg · `#d4be98` fg · `#7daea3` blue · `#d8a657` yellow · `#ea6962` red · `#a9b665` green · `#d3869b` purple

## License

[MIT](LICENSE)
