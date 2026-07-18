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

> **Check disk first:** on home-desktop, `nvme1n1` is the Windows drive — NixOS goes on `nvme0n1`.
> Run `lsblk` on the live system and verify `hosts/home-desktop/disk-config.nix` targets the right disk.

---

## After install

```bash
nixup        # nh os switch — should succeed with no changes
nixsrch git  # verifies nix search works
nvidia-smi   # desktop only
```

See `TODO.md` section 8 for the full post-install checklist.

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

On POST hit `F8`, `F11`, or `F12`. Look for `Linux Boot Manager` or an entry referencing `nvme0n1`. If it boots, go into BIOS and move it to the top permanently.

**Step 2 — re-register the EFI entry from the NixOS ISO**

```bash
lsblk   # confirm partition layout

efibootmgr -c -d /dev/nvme0n1 -p 1 \
  -L "Linux Boot Manager" \
  -l '\EFI\systemd\systemd-bootx64.efi'

efibootmgr -v   # verify entry appears
reboot
```

**Step 3 — fallback EFI path (boards that ignore EFI variables)**

Some ASUS/MSI boards don't persist EFI variables written by the OS:

```bash
mount /dev/nvme0n1p1 /mnt
mkdir -p /mnt/EFI/BOOT
cp /mnt/EFI/systemd/systemd-bootx64.efi /mnt/EFI/BOOT/BOOTX64.EFI
umount /mnt
reboot
```
