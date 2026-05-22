# TODO — Before First Use

Things to do before running `nixos-rebuild switch` for the first time.

---

## 1. Generate hardware configurations (required per machine)

- [x] `home-desktop` — real config (Intel i7-13700K, nvme, kvm-intel)
- [ ] `work-laptop` — still a placeholder, replace on first install
- [ ] `minimal` — still a placeholder, replace on first install

On each target machine, boot the NixOS ISO, partition, mount at `/mnt`, then run:

```bash
sudo nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix hosts/<name>/hardware-configuration.nix
```

---

## ~~3. Set your monitor configuration~~ DONE

- [x] `home-desktop` monitors set (DP-2 portrait 4K + DP-3 1440p@165)
- [x] Waybar clock timezone set to `Pacific/Auckland`

---

## 6. Packages not yet in nixpkgs (may need overlays)

- [x] `gruvbox-material-gtk-theme` → `theme.nix` has fallback to `pkgs.gruvbox-dark-gtk`; handled
- [x] `zen-browser` → using flake input directly, no nixpkgs needed
- [x] `latencyflex` → removed from `gaming.nix`
- [ ] `gpu-screen-recorder` → in `productivity.nix`; verify package name builds on first switch
- [ ] `itch` → in `gaming.nix`; verify package name (sometimes `itch-app`) on first build
- [ ] `apollo-bin` (streaming server) → not added; needs custom derivation in `pkgs/` if wanted

---

## 7. Install with nixos-anywhere (automated)

Boot the NixOS ISO, connect ethernet, then:

```bash
# On the live system — set a password and note the IP
passwd nixos
ip addr
```

Then from any machine with Nix installed (WSL, another Linux box, etc.):

```bash
# One command installs everything — partitions, formats, and installs NixOS
nix run github:nix-community/nixos-anywhere -- \
  --flake github:maxabbot/nix#home-desktop \
  nixos@<ip>
```

nixos-anywhere will:
1. SSH into the live ISO
2. Partition and format the disk using `hosts/home-desktop/disk-config.nix`
3. Run `nixos-install` with your flake
4. Reboot into the finished system

> **Note:** Default disk is `/dev/nvme0n1`. If yours is different (check with `lsblk`),
> update `device` in `hosts/home-desktop/disk-config.nix` first.

**Manual alternative** (if nixos-anywhere isn't available):

```bash
# SSH in, then run the install guide steps manually
ssh nixos@<ip>
# Follow docs/guides/nix-install.md
```

---

## 9. Secrets management (when deploying for real)

Once you're no longer testing — real machine, real credentials:

- Add `agenix` to flake inputs and the NixOS module
- Create `secrets/secrets.nix` with the host's public key (`/etc/ssh/ssh_host_ed25519_key.pub`)
- Encrypt hashed password: `agenix -e secrets/hashed-password.age` (use `mkpasswd` output)
- Replace `initialPassword = "123"` with `hashedPasswordFile = config.age.secrets.hashedPassword.path`
- Populate `sshKeys` so `deploy.sh` can connect
- Add a GPG key and fill in `signingkey` in `flake.nix`

See fufexan/dotfiles `secrets/` for a clean reference.

---

## 8. Post-install checks

- [ ] Hyprland/Sway starts on login (SDDM should appear)
- [ ] Waybar status bar visible with correct Gruvbox colours
- [ ] Fuzzel launcher opens with `Super+D`
- [ ] Gruvbox Material theme applied in GTK apps
- [ ] Kitty terminal opens with correct font and colours
- [ ] `git log` shows Gruvbox delta diffs
- [ ] `nixup` alias works (`sudo nixos-rebuild switch --flake /etc/nixos#$(hostname)`)
- [ ] `nix search nixpkgs <pkg>` works
- [ ] Night light activates at sunset (Gammastep)
- [ ] Podman/Docker alias works (`d ps`)
- [ ] NVIDIA driver loaded: `nvidia-smi` shows GPU
- [ ] Steam launches and Proton is available
- [ ] Syncthing web UI accessible at `localhost:8384`
- [ ] Swaync notifications appear (`notify-send test`)

---

## 10. Future improvements

### Low effort, high value

- [ ] **Secrets management** (sops-nix or agenix) — see `docs/config-comparison.md` for setup steps; unblocks real deployment
- [x] **`nh`** — added to system packages; `nixup` alias and `sysup` function updated
- [x] **`nix-index` + `comma`** — `nix-index-database` flake input added; `, <pkg>` to run anything; `nix locate <file>` to find packages
- [x] **`statix` + `deadnix` in CI** — `lint` job added to `.github/workflows/ci.yml`

### Medium value

- [ ] **`nixos-hardware` modules** — minimal value for `home-desktop` (everything already configured manually); revisit for `work-laptop` once hardware is known
- [ ] **GPG commit signing** — fill in `signingkey` in `flake.nix` and configure `programs.gpg` in HM
- [ ] **Backups** — `restic` or `borgbackup` for off-disk backup; BTRFS snapshots don't protect against disk failure
- [x] **Specialisations for `work-laptop`** — `powersave` boot entry added; overrides TLP to all-powersave governors
- [x] **Dev shell for the config** — `nix develop` in repo root gives nixfmt, statix, deadnix, nil
