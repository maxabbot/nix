# TODO

---

## Before deploying a new host

### Hardware configuration

`framework` still has a placeholder `hardware-configuration.nix` (work-laptop's is real — ThinkBook via the portable USB SSD). Replace on first install:

```bash
sudo nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix hosts/<name>/hardware-configuration.nix
```

### Secrets

- Finish the sops move (config landed 2026-09-28, `hosts/common/optional/sops.nix`):
  - Install each host's age key from `.bootstrap/<host>/key.txt` (gitignored) *before* that host's next rebuild: `sudo install -Dm600 key.txt /var/lib/sops-nix/key.txt`, then delete the staged copy
  - Rotate the password (the old hash is in git history): `passwd` on each machine, then store the new hash so fresh installs get it — `sops set secrets/common.yaml '["max-password-hash"]' "\"$(mkpasswd -m yescrypt)\""` (`secrets/common.yaml` holds `REPLACE_ME` until then)
  - Back up the admin key (`~/.config/sops/age/keys.txt`, shared with homelab) outside both repos
- Populate `sshKeys` in `custom.base` before enabling `services.openssh` for remote login
- GPG commit signing: add a `signingkey` hmArg in `flake.nix` and consume it in `home/max/git.nix` (the old empty stub was removed as dead code)

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

> home-desktop targets `/dev/nvme1n1` (the 1.8 TB NixOS disk) — `/dev/nvme0n1` is the **Windows** disk, don't touch it. Confirm with `lsblk` (match by size) before running; disko reformats whatever `hosts/<host>/disk-config.nix` points at.

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

## Up next

- [ ] **Theming: Hyprland windows + DMS** — bring DMS in line with the Hyprland window styling; add transparency to DMS panels/popouts
- [ ] **DMS Settings as a drop-down** instead of a window — started in 2ba26d8, still needs fixing
- [ ] **Fix DMS display settings**
- [ ] **Cursor sharing with the laptop (lan-mouse)** — configured, still needs pairing + testing
- [ ] **Fix game mode**
- [ ] **Fix `Super+Q` closing every instance** — should close only the focused window
- [ ] **Backblaze B2 backups** of home-desktop and framework (see Backups below)

## Future improvements

- [x] **Secrets management** — sops-nix (2026-09-28); key install + password rotation still pending, see Secrets above
- [ ] **GPG commit signing** — `programs.gpg` in HM + `signingkey` in flake
- [ ] **Backups** — `restic` → Backblaze B2 (home-desktop + framework); BTRFS snapshots don't cover disk failure. B2 credentials want secrets management first
- [ ] **Pin Stylix** — tracking `master` while nixpkgs/HM are on 26.05; once a `release-26.05` branch exists, pin it and drop the two `enableReleaseChecks = false` lines plus the kmscon `disabledModules` workaround in `hosts/common/optional/stylix.nix`
- [x] **Decide what `plymouth.nix` is for** — imported on all four hosts, themed by Stylix instead of the adi1090x "spin" theme.
