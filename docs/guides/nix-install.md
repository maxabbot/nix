# NixOS Install Guide

Install using nixos-anywhere — one command from any machine with Nix (including WSL).

---

## Automated install (nixos-anywhere)

**On the live ISO:**
```bash
passwd nixos   # set a temporary password
ip addr        # note the IP address
```

**From your local machine or WSL:**
```bash
nix --extra-experimental-features 'nix-command flakes' run github:nix-community/nixos-anywhere -- \
  --flake .#home-desktop \
  --build-on remote \
  nixos@<ip>
```

> `--build-on remote` shifts compilation to the target machine, avoiding OOM on WSL.
> If the connection drops mid-copy, re-run — disko will re-format and restart.

nixos-anywhere SSHs in, runs disko to partition/format (`hosts/home-desktop/disk-config.nix`), then installs NixOS.

> **Check disk first:** on home-desktop NixOS lives on **`nvme1n1`** (the 1.8 TB disk, which
> `hosts/home-desktop/disk-config.nix` targets) — **`nvme0n1` is the 477 GB Windows drive, do not
> touch it.** NVMe names can swap between boots/firmware changes, so run `lsblk` on the live
> system and match by **size** before letting disko loose.

---

## After install

```bash
nixup        # nh os switch — should succeed with no changes
nixsrch git  # verifies nix search works
nvidia-smi   # desktop only
```

See the post-install checklist in `TODO.md`.

---

## Troubleshooting

### `error: experimental Nix feature 'nix-command' is disabled`

Enable permanently so you never need the flag again:

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

On a multi-user install (Determinate Systems installer), edit `/etc/nix/nix.conf` and restart the daemon:

```bash
sudo sh -c 'echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf'
sudo systemctl restart nix-daemon
```

---

### No boot entry after install (dual-drive)

nixos-anywhere completes but NixOS doesn't appear in the firmware boot menu. Common on two-NVMe systems where the firmware defaults to the other drive.

**Step 1 — one-time boot menu (no ISO needed)**

On POST hit `F8`, `F11`, or `F12`. Look for `Limine` (or `Linux Boot Manager` on the systemd-boot `minimal` host) or an entry referencing the NixOS disk. If it boots, go into BIOS and move it to the top permanently.

**Step 2 — re-register the EFI entry from the NixOS ISO**

The GUI hosts boot Limine; its NVRAM entry is labelled `Limine` and points at `\EFI\limine\BOOTX64.EFI` (`minimal` still uses systemd-boot at `\EFI\systemd\systemd-bootx64.efi`):

```bash
lsblk   # confirm which disk holds the ESP (home-desktop: nvme1n1p1)

efibootmgr -c -d /dev/nvme1n1 -p 1 \
  -L "Limine" \
  -l '\EFI\limine\BOOTX64.EFI'

efibootmgr -v   # verify entry appears
reboot
```

**Step 3 — fallback EFI path (boards that ignore EFI variables)**

Some ASUS/MSI boards don't persist EFI variables written by the OS:

```bash
mount /dev/nvme1n1p1 /mnt
mkdir -p /mnt/EFI/BOOT
cp /mnt/EFI/limine/BOOTX64.EFI /mnt/EFI/BOOT/BOOTX64.EFI
umount /mnt
reboot
```

(work-laptop's USB install already lives at the fallback path — `efiInstallAsRemovable` — see the efibootmgr note in `hosts/work-laptop/default.nix` to re-pin its NVRAM entry.)
