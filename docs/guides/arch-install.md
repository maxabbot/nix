# Arch Linux Install Guide

End-to-end walkthrough for a fresh Arch install using this repository.
The process follows the three-layer architecture:

```
Layer 1 — Bootstrap (archinstall)      boot ISO → partition → base system
Layer 2 — System config (Ansible)      packages, services, drivers
Layer 3 — User environment (Chezmoi)   dotfiles, shell, editor, WM
```

Layers 2 and 3 are both handled by `setup.sh` after first boot.

---

## Prerequisites

- Arch Linux ISO burned to USB (`dd` or Ventoy)
- Target disk identified (run `lsblk` after booting live media)
- Internet connection (Ethernet is simplest; Wi-Fi steps below)
- The repo cloned or available to fetch from GitHub

---

## Layer 1 — Bootstrap (archinstall)

### 1. Boot the Arch live environment

Boot the machine from the Arch ISO. You will land at a root shell.

### 2. Connect to the internet

**Ethernet**: usually auto-configured via DHCP. Verify with `ping archlinux.org`.

**Wi-Fi**:
```bash
iwctl
  device list
  station wlan0 scan
  station wlan0 get-networks
  station wlan0 connect "SSID"
  exit
```

### 3. Get the repo config files

```bash
# Sync package databases first
pacman -Sy git

# Clone the repo
git clone https://github.com/maxabbot/linux-setup-scripts.git
cd linux-setup-scripts/bootstrap/archinstall
```

### 4. Review and customise `user-configuration.json`

Open the config before running — at minimum check these fields:

**Disk configuration** — the config is set to auto-detect your disk. When you run archinstall, you will be prompted interactively:
1. archinstall will list available disks
2. Select your target disk (e.g., `/dev/sda`)
3. Choose your partition scheme (the default `default_layout` uses Btrfs with subvolumes)
4. Review and confirm

Confirm your target disk before archinstall starts:
```bash
lsblk
```

> **Warning**: archinstall will prompt you to confirm disk wipe operations. Review carefully as this will erase data.

**Graphics driver** — change `profile_config.gfx_driver` to match your GPU:

| GPU | Value |
|-----|-------|
| NVIDIA (proprietary) | `"Nvidia (proprietary)"` ← default |
| AMD | `"AMD / ATI (open-source)"` |
| Intel | `"Intel (open-source)"` |
| Mixed / safe | `"All open-source"` |

**Desktop** — `profile_config.profile.details` defaults to `["Hyprland"]`. Change to `["Sway"]` if preferred.

**Timezone** — defaults to `"Pacific/Auckland"`. Update to your zone, e.g. `"Europe/London"`.

**Locale** — defaults to `"en_NZ"`. Update `locale_config.sys_lang` for your region, e.g. `"en_US"` or `"en_GB"`.

**Mirror region** — update `mirror_config.mirror_regions` to a region near you to improve download speeds.

You can edit in-place:
```bash
nano user-configuration.json
```

### 5. Create your credentials file

```bash
cp user-credentials.json.example user-credentials.json
nano user-credentials.json
```

Set your username and password. This file is gitignored — never commit it.

### 6. Run archinstall

```bash
archinstall --config user-configuration.json --creds user-credentials.json
```

**What the config installs by default:**

| Setting | Value |
|---------|-------|
| Bootloader | Grub |
| Filesystem | Btrfs with subvolumes (`@`, `@home`, `@log`, `@pkg`, `@snapshots`) |
| Mount options | `compress=zstd`, `noatime` |
| Boot partition | 1 GiB FAT32 at `/boot` |
| Kernels | `linux` + `linux-lts` |
| Extra repositories | `multilib` |
| Audio | PipeWire |
| Network | NetworkManager |
| Base packages | `base-devel`, `git`, `neovim`, `networkmanager`, `openssh`, `reflector`, `ansible`, `python`, `python-pip` |
| NTP | Enabled |

`archinstall` will show a summary screen before writing anything. Review it, then select **Install**.

### 7. Reboot into the new system

When archinstall finishes, choose **No** on the chroot prompt (unless you need to make manual changes), then:

```bash
reboot
```

Remove the USB drive when the machine restarts.

---

## Layer 2 & 3 — System Config and Dotfiles (`setup.sh`)

Log in as the user you created during archinstall.

### 1. Verify network

```bash
ping -c 3 archlinux.org
```

If NetworkManager didn't connect automatically:
```bash
nmtui    # text-mode network manager UI
```

### 2. Clone the repo (if not already on disk)

The archinstall step cloned into the live environment — that's gone after reboot. Clone again:

```bash
cd ~
git clone https://github.com/maxabbot/linux-setup-scripts.git
cd linux-setup-scripts
```

### 3. Run `setup.sh`

```bash
chmod +x setup.sh
./setup.sh
```

The script walks through four steps:

**Step 1 — Prerequisites**
Installs `git`, `ansible`, `python`, `python-pip`, and `chezmoi` if any are missing.
Installs Ansible Galaxy collections from `system/requirements.yml`.

**Step 2 — Profile selection**

```
1) Home Desktop  — base + dev + productivity + nvidia + gaming
2) Work Laptop   — base + dev + productivity
3) Minimal       — base only
4) Custom        — choose roles interactively
```

| Profile | Power management | Docker | NVIDIA/CUDA | Gaming |
|---------|-----------------|--------|-------------|--------|
| Home Desktop | `power-profiles-daemon` | Yes | Yes | Yes |
| Work Laptop | `tlp` | Yes | No | No |
| Minimal | — | — | — | — |

Pick the profile that matches your hardware. For a custom build, option 4 lets you select individual Ansible roles (`base`, `development`, `productivity`, `nvidia`, `gaming`).

**Step 3 — Ansible system playbook**
Runs `system/playbooks/site.yml` against `localhost` with the selected profile.
You will be prompted for your sudo password (`--ask-become-pass`).

The playbook:
1. Updates system packages (`pacman -Syu`)
2. Sets up the AUR helper (via `roles/aur`)
3. Applies selected roles in order: `base → development → productivity → nvidia → gaming`

**Step 4 — Chezmoi dotfiles**
Three options are presented:
- **Yes** — applies all dotfiles from `user/` immediately
- **Dry run** — preview changes without writing anything
- **Skip** — apply manually later

Chezmoi manages: `~/.zshrc`, `~/.bashrc`, Neovim config, Hyprland/Sway config, Waybar config.

### 4. Reboot

```bash
sudo reboot
```

---

## Post-setup first steps

After rebooting:

**Shell**
```bash
# Powerlevel10k prompt wizard runs automatically on first Zsh launch
# If it doesn't, run manually:
p10k configure
```

**Neovim**
```bash
nvim
# lazy.nvim auto-installs all plugins on first launch
# Inside Neovim:
# :Mason   — verify LSP servers installed (pyright, rust-analyzer, tsserver, bashls, lua_ls)
# :Lazy    — confirm plugins
# :checkhealth — diagnose issues
```

**Verify services**
```bash
systemctl status NetworkManager bluetooth
systemctl --user status pipewire wireplumber

# NVIDIA (Home Desktop profile only)
nvidia-smi
systemctl status nvidia-persistenced

# Power management
systemctl status power-profiles-daemon   # home_desktop
systemctl status tlp                     # work_laptop
```

**Window manager**
```bash
Hyprland    # or: sway
```

**GitHub authentication**

Generate an SSH key and add it to your GitHub account:

```bash
# Generate key (replace with your GitHub email)
ssh-keygen -t ed25519 -C "you@example.com"

# Start the agent and load the key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Print the public key — paste this into GitHub → Settings → SSH keys
cat ~/.ssh/id_ed25519.pub
```

Add the key at <https://github.com/settings/ssh/new>, then verify:

```bash
ssh -T git@github.com
# Expected: "Hi <username>! You've successfully authenticated..."
```

Switch any existing HTTPS remote to SSH:

```bash
# Inside the cloned repo
git remote set-url origin git@github.com:maxabbot/linux-setup-scripts.git
```

Configure git identity if not already set:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
```

---

## Running individual layers again later

```bash
# Re-run full system playbook
ansible-playbook system/playbooks/site.yml -i system/inventory/hosts.yml \
  -l home_desktop --ask-become-pass

# Re-run a single role
ansible-playbook system/playbooks/development.yml -i system/inventory/hosts.yml \
  --ask-become-pass

# Re-run with specific tags
ansible-playbook system/playbooks/site.yml -i system/inventory/hosts.yml \
  --tags "base,development" --ask-become-pass

# Re-apply dotfiles
chezmoi apply

# Preview dotfile changes
chezmoi diff
```

---

## Troubleshooting

**archinstall fails immediately** — check that the target disk path in `user-configuration.json` matches `lsblk` output.

**No network after reboot** — run `nmtui` to connect. Ensure `NetworkManager.service` is enabled (`sudo systemctl enable --now NetworkManager`).

**Ansible playbook fails on AUR role** — the AUR role requires a non-root user in the `wheel` group with passwordless sudo or a working `--ask-become-pass` prompt. Confirm your user is in `wheel`: `groups $USER`.

**Hyprland/Sway won't start** — confirm the display server: `echo $XDG_SESSION_TYPE`. For Wayland compositors, log in from a TTY (not an existing Wayland/X session) and launch directly.

**NVIDIA issues** — the `nvidia` role is only applied under the `home_desktop` profile. For hybrid laptops (NVIDIA + Intel/AMD), check `roles/nvidia/vars/main.yml` for prime-related packages.
