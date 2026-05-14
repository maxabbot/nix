# Post-Installation Guide

This guide covers the recommended steps after `nixos-rebuild switch` completes
or after `nixos-install` and first reboot.

## 1. Reboot

```bash
sudo reboot
```

Ensures kernel modules, NVIDIA drivers, and system services load correctly.

## 2. Verify Services

```bash
# Core
systemctl status NetworkManager
systemctl status bluetooth
systemctl --user status pipewire wireplumber

# NVIDIA (if installed)
nvidia-smi
systemctl status nvidia-persistenced

# Power management
systemctl status power-profiles-daemon   # desktop
systemctl status tlp                     # laptop

# Virtualisation (if enabled)
systemctl status podman.socket
systemctl status libvirtd
```

## 3. SSH Key Setup

Home Manager enables SSH agent via GPG agent (`IdentityAgent /run/user/1000/gnupg/S.gpg-agent.ssh`).
Generate a key if needed:

```bash
ssh-keygen -t ed25519 -C "your.email@example.com"
ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub   # add to GitHub / GitLab
```

## 4. Shell First Launch

Zsh is configured by Home Manager. On first Zsh launch:

```bash
# Verify zoxide database initialises
zoxide query --list

# Verify starship prompt renders with Gruvbox colours
echo $STARSHIP_SHELL

# Verify NixOS aliases work
nixup   # should run nixos-rebuild switch
```

## 5. Zed First Launch

```bash
zed .
```

On first launch Zed auto-installs the extensions defined in `auto_install_extensions`
(gruvbox-material, nix, ruff, etc.) and downloads LSP servers for open file types.
Verify:
- Extensions panel — all listed extensions show as installed
- Open a `.nix` file — `nil` LSP should activate (bottom status bar)

## 6. Window Manager

SDDM starts automatically. Log in to the Hyprland session.

Key bindings (see `docs/SHORTCUTS.md` for the full reference):
- `Super+Return` — Terminal (kitty)
- `Super+D` — App launcher (fuzzel)
- `Super+Q` — Close window
- `Super+1–9` — Switch workspace

Monitor configuration is set in `hosts/<name>/default.nix`. After updating,
run `nixup` to apply changes.

## 7. Test Hardware

```bash
# Audio
speaker-test -t wav -c 2

# GPU
vulkaninfo | head -30
nvidia-smi               # NVIDIA only

# Network
ping -c 4 nixos.org
```

## 8. Snapshots

Create a baseline Btrfs snapshot (home-desktop uses BTRFS with snapper):

```bash
sudo snapper -c root create --description "post-install baseline"
sudo snapper -c root list
```

## 9. Rebuilding / Updating

```bash
# Apply any config changes
nixup                           # alias for nixos-rebuild switch

# Update all flake inputs (nixpkgs, home-manager, etc.)
flkupd                          # alias for nix flake update

# Full update + rebuild
flkupd && nixup

# Garbage collect old generations
gcclean                         # alias for nix-collect-garbage -d
```

## 10. Adding Packages

1. Find the nixpkgs name: `nixsrch <name>` (alias for `nix search nixpkgs`)
2. Add to the relevant module in `modules/nixos/<role>.nix`
3. Run `nixup`

See `CLAUDE.md` for the full guide.
