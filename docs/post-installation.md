# Post-Installation Guide

This guide covers the recommended steps after running `setup.sh` (or after manually
running the Ansible playbook and Chezmoi apply).

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
systemctl status nvidia-persistenced
nvidia-smi

# Power management
systemctl status power-profiles-daemon   # desktop
systemctl status tlp                     # laptop

# Docker / libvirt (if enabled)
systemctl status docker
systemctl status libvirtd
```

## 3. Configure Git & SSH

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

ssh-keygen -t ed25519 -C "your.email@example.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub    # add to GitHub / GitLab
```

## 4. Shell First Launch

If Chezmoi applied the dotfiles, Zsh is already your default shell. On first launch:

```bash
# Powerlevel10k will auto-run its configuration wizard
p10k configure

# Verify plugins loaded (managed by Antidote)
antidote list
```

If you skipped Chezmoi, apply dotfiles manually:

```bash
chezmoi init --source ./user --apply
```

## 5. Neovim First Launch

Open Neovim — lazy.nvim will auto-install all plugins on first run:

```bash
nvim
```

Then inside Neovim:

- `:Lazy` — verify all plugins installed
- `:Mason` — verify LSP servers (pyright, rust-analyzer, tsserver, bashls, lua_ls)
- `:checkhealth` — diagnose any issues

## 6. Window Manager

### Hyprland

```bash
Hyprland
```

Key bindings (Super = Mod key):
- `Super + Return` — Terminal (kitty)
- `Super + D` — App launcher (fuzzel)
- `Super + Q` — Close window
- `Super + 1-9` — Switch workspace

### Sway

```bash
sway
```

Same key bindings apply (i3-style).

### Monitor Configuration

If you have a multi-monitor setup, edit your Chezmoi template variables:

```bash
chezmoi edit-config
```

Update the `[data.monitors]` section:

```toml
[data.monitors]
  primary = "DP-1, preferred, 0x0, 1"
  secondary = "HDMI-A-1, preferred, 2560x0, 1"
```

Then re-apply:

```bash
chezmoi apply
```

## 7. Application Setup

### Browsers
- Firefox is the default — sign in to sync bookmarks/extensions
- If `enable_secondary_browsers` was enabled: Brave and Zen are also installed

### Communication
- Thunderbird — configure email accounts
- Element — sign in to Matrix

### Gaming (if enabled)
- Steam — sign in, enable Proton (Settings > Compatibility)
- Heroic — link Epic Games / GOG accounts
- Test controller with `evtest`

### Creative (if enabled)

- GIMP, Krita, Inkscape are ready to use

## 8. Test Hardware

```bash
# Audio
speaker-test -t wav -c 2

# GPU
glxinfo | grep "OpenGL renderer"
vulkaninfo | head -20

# Network
ping -c 4 archlinux.org
```

## 9. System Backup

Create a baseline Btrfs snapshot (if using the bootstrap config):

```bash
sudo btrfs subvolume snapshot / /.snapshots/post-install-$(date +%Y%m%d)
```

Or with Timeshift:

```bash
sudo timeshift --create --comments "Post-installation baseline"
```

## 10. Re-Running the Setup

You can safely re-run any layer at any time:

```bash
# Re-run full system playbook
ansible-playbook system/playbooks/site.yml -i system/inventory/hosts.yml \
  -l home_desktop --ask-become-pass

# Re-run a single role
ansible-playbook system/playbooks/development.yml -i system/inventory/hosts.yml \
  --ask-become-pass

# Re-apply dotfiles
chezmoi apply

# Check what changed
chezmoi diff
```

## 11. Customisation

### Adding Packages

Edit the relevant role's `vars/main.yml`:

```
system/roles/<role>/vars/main.yml
```

### Toggling Features

Edit `system/inventory/group_vars/all.yml` or your profile's group vars:

```yaml
enable_docker: true
enable_cuda_stack: true
```

### Adding Dotfiles

Add files to the `user/` Chezmoi source directory, then apply:

```bash
chezmoi add ~/.config/some-app/config.toml
chezmoi apply
```

## Useful Resources

- [Arch Wiki](https://wiki.archlinux.org/)
- [Ansible Documentation](https://docs.ansible.com/)
- [Chezmoi Documentation](https://www.chezmoi.io/)
- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Repository Issues](https://github.com/maxabbot/linux-setup-scripts/issues)
