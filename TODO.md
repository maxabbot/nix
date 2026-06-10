# TODO

---

## Before deploying a new host

### Hardware configuration

`work-laptop` and `minimal` still have placeholder `hardware-configuration.nix` files. Replace on first install:

```bash
sudo nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix hosts/<name>/hardware-configuration.nix
```

### Secrets

- Move `hashedPassword` out of the host files into agenix or sops-nix (`hashedPasswordFile`) — the current hash is committed to git history, so rotate the password once secrets land
- Populate `sshKeys` in `custom.base` before enabling `services.openssh` for remote login
- GPG commit signing: add a `signingkey` hmArg in `flake.nix` and consume it in `home/max/git.nix` (the old empty stub was removed as dead code)

Full setup: add `agenix` to flake inputs, create `secrets/secrets.nix` with the host's SSH public key (`/etc/ssh/ssh_host_ed25519_key.pub`), then:

```bash
agenix -e secrets/hashed-password.age  # paste mkpasswd output
```

See fufexan/dotfiles `secrets/` for a clean reference.

---

## Install (nixos-anywhere)

Boot the NixOS ISO, connect ethernet:

```bash
passwd nixos && ip addr   # note the IP
```

From any machine with Nix (WSL, etc.):

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake github:maxabbot/nix#home-desktop \
  nixos@<ip>
```

> Default disk is `/dev/nvme0n1` — check with `lsblk` and update `hosts/home-desktop/disk-config.nix` if needed.

---

## Post-install checklist

- [ ] Hyprland starts, SDDM greeter appears on correct monitor
- [ ] Waybar visible with correct Gruvbox colours
- [ ] Fuzzel opens with `Super+D`
- [ ] Gruvbox Material theme applied in GTK apps
- [ ] Kitty opens with correct font and colours
- [ ] `git log` shows Gruvbox delta diffs
- [ ] `nixup` alias works
- [ ] Night light activates at sunset (Gammastep)
- [ ] Podman/Docker alias works (`d ps`)
- [ ] `nvidia-smi` shows GPU
- [ ] Steam launches, Proton available
- [ ] Syncthing UI at `localhost:8384`
- [ ] Quickshell notifications work (`notify-send test` — served by Shell.qml's NotificationServer)
- [ ] Apollo streaming UI at `https://localhost:47990`

---

## Future improvements

- [ ] **Secrets management** — sops-nix or agenix; unblocks real deployment
- [ ] **`nixos-hardware` modules** — revisit for `work-laptop` once hardware is known
- [ ] **GPG commit signing** — `programs.gpg` in HM + `signingkey` in flake
- [ ] **Backups** — `restic` or `borgbackup`; BTRFS snapshots don't cover disk failure
