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
sudo nix --extra-experimental-features 'nix-command flakes' run github:nix-community/nixos-anywhere -- \
  --flake .#home-desktop \
  --build-on remote \
  nixos@<ip>
```

> **WSL users:** `--build-on remote` shifts compilation to the target machine, avoiding OOM kills locally (e.g. building boost).
> If running from WSL without flakes enabled globally, the `--extra-experimental-features` flag is required.
> If WSL disconnects mid-copy, just re-run — disko will re-format and the copy will restart.

That's it. nixos-anywhere SSHs in, runs disko to partition/format the disk
(as defined in `hosts/home-desktop/disk-config.nix`), then installs NixOS.

> **Check disk name first:** on home-desktop, `nvme1n1` is the Windows drive — NixOS goes on `nvme0n1`.
> Run `lsblk` on the live system and verify `hosts/home-desktop/disk-config.nix` targets the correct disk.

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

---

## Troubleshooting

### `error: experimental Nix feature 'nix-command' is disabled`

Your Nix install doesn't have `nix-command` and `flakes` enabled globally.
Fix it for the current command by prefixing the flag:

```bash
nix --extra-experimental-features 'nix-command flakes' run github:nix-community/nixos-anywhere -- \
  --flake github:maxabbot/nix#home-desktop \
  --build-on remote \
  nixos@<ip>
```

Or enable permanently so you never need the flag again:

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

On a multi-user Nix install (e.g. the Determinate Systems installer), edit `/etc/nix/nix.conf` instead and restart the daemon:

```bash
sudo sh -c 'echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf'
sudo systemctl restart nix-daemon
```

---

### No boot option after install (dual-drive / dual-boot)

nixos-anywhere completes successfully but the machine has no NixOS entry in the
firmware boot menu. On a two-NVMe system (e.g. Windows on `nvme1n1`, NixOS on
`nvme0n1`) the firmware often defaults to the Windows drive and ignores the EFI
entry systemd-boot wrote to `nvme0n1p1`.

**Step 1 — check the one-time boot menu first (no ISO needed)**

On POST hit the one-time boot key (`F8`, `F11`, or `F12` depending on board).
Look for `Linux Boot Manager` or an entry referencing `nvme0n1`. If it boots,
go into BIOS and move it to the top of the boot order permanently.

**Step 2 — re-register the EFI entry from the NixOS ISO**

Boot the NixOS ISO, then:

```bash
# Confirm partition layout
lsblk

# Register systemd-boot with the firmware
efibootmgr -c -d /dev/nvme0n1 -p 1 
  -L "Linux Boot Manager" \
  -l '\EFI\systemd\systemd-bootx64.efi'

# Verify the new entry appears and reboot
efibootmgr -v
reboot
```

**Step 3 — fallback EFI path (boards that ignore EFI variables)**

Some ASUS / MSI boards do not persist EFI variables written by the OS.
Copying to the universal fallback path forces the firmware to find it:

```bash
mount /dev/nvme0n1p1 /mnt
mkdir -p /mnt/EFI/BOOT
cp /mnt/EFI/systemd/systemd-bootx64.efi /mnt/EFI/BOOT/BOOTX64.EFI
umount /mnt
reboot
```
