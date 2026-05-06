# NixOS Install Guide

End-to-end walkthrough for a fresh NixOS installation using this flake.

---

## Recommended: Automated install with nixos-anywhere

nixos-anywhere + disko handle partitioning, formatting, and installation in one command
from any machine with Nix installed (including WSL on Windows).

### Steps

**1. Boot the NixOS ISO**, connect ethernet, then in the live shell:
```bash
passwd nixos   # set a temporary password
ip addr        # note the IP address
```

**2. From your local machine** (or WSL):
```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake github:maxabbot/nix#home-desktop \
  nixos@<ip>
```

That's it. nixos-anywhere SSHs in, runs disko to partition/format the disk
(as defined in `hosts/home-desktop/disk-config.nix`), then installs NixOS.

> **Check disk name first:** default is `/dev/nvme0n1`. Run `lsblk` on the live system
> and update `hosts/home-desktop/disk-config.nix` if your disk is different before running.

---

## Manual install (fallback)

Use this if nixos-anywhere isn't available or you need custom partitioning.

### Prerequisites

- NixOS minimal ISO burned to USB (`dd` or Ventoy)
- Target disk identified (`lsblk` after booting live media)
- Internet connection (Ethernet recommended; Wi-Fi via `wpa_supplicant`)

---

## 1. Boot the ISO

Boot from USB. The live environment starts a root shell (or minimal desktop on the graphical ISO).

Connect to Wi-Fi if needed:
```bash
wpa_passphrase "SSID" "password" > /etc/wpa_supplicant.conf
wpa_supplicant -B -i wlp3s0 -c /etc/wpa_supplicant.conf
dhclient wlp3s0
```

---

## 2. Partition & Format

**Example for home-desktop (BTRFS, GPT + EFI):**

```bash
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 512MB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary 512MB 100%

mkfs.fat -F 32 -n BOOT /dev/nvme0n1p1
mkfs.btrfs -L nixos /dev/nvme0n1p2

# Create subvolumes
mount /dev/nvme0n1p2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@snapshots
umount /mnt

# Mount with options
mount -o subvol=@,compress=zstd,noatime /dev/nvme0n1p2 /mnt
mkdir -p /mnt/{home,nix,.snapshots,boot}
mount -o subvol=@home,compress=zstd,noatime /dev/nvme0n1p2 /mnt/home
mount -o subvol=@nix,compress=zstd,noatime  /dev/nvme0n1p2 /mnt/nix
mount -o subvol=@snapshots,compress=zstd    /dev/nvme0n1p2 /mnt/.snapshots
mount /dev/nvme0n1p1 /mnt/boot
```

**Example for work-laptop (ext4):**

```bash
parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart ESP fat32 1MB 512MB
parted /dev/sda -- set 1 esp on
parted /dev/sda -- mkpart primary ext4 512MB 100%

mkfs.fat -F 32 -n BOOT /dev/sda1
mkfs.ext4 -L nixos /dev/sda2

mount /dev/sda2 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot
```

---

## 3. Generate Hardware Configuration

```bash
nixos-generate-config --root /mnt
```

This produces `/mnt/etc/nixos/hardware-configuration.nix`. You'll copy this into
the flake repo.

---

## 4. Clone the Flake

Enable flakes on the live system:
```bash
nix-shell -p git
```

Clone and place:
```bash
git clone https://github.com/maxabbot/nix.git /mnt/etc/nixos
cp /mnt/etc/nixos-generated/hardware-configuration.nix \
   /mnt/etc/nixos/hosts/<hostname>/hardware-configuration.nix
```

---

## 5. Personalise Before Installing

Inside `/mnt/etc/nixos`, update **at minimum**:

1. `hosts/<name>/hardware-configuration.nix` — generated above
2. `hosts/<name>/default.nix` — set `git.name`, `git.email`, `monitors.*`, `location.*`

See `TODO.md` for the full pre-install checklist.

---

## 6. Install

```bash
nixos-install --flake /mnt/etc/nixos#home-desktop
# or: nixos-install --flake /mnt/etc/nixos#work-laptop
```

Set the root password when prompted. Then reboot:

```bash
reboot
```

---

## 7. First Boot

Log in via SDDM, open a terminal, and verify:

```bash
nixup        # runs nixos-rebuild switch — should succeed with no changes
nixsrch git  # verifies nix flake search works
nvidia-smi   # desktop only
```

See `docs/post-installation.md` for the full post-install checklist.
