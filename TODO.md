# TODO

---

## Before deploying a new host

### Framework

Install prep and the full test list: [`docs/guides/framework-post-install.md`](docs/guides/framework-post-install.md).

### Hardware configuration

Both hosts have a real `hardware-configuration.nix` (framework's landed 2026-11-02). For a new host, generate it on first install:

```bash
sudo nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix hosts/<name>/hardware-configuration.nix
```

### Secrets

- Finish the sops move (config landed 2026-09-28, `hosts/common/optional/sops.nix`):
  - ~~Install each host's age key~~ — done: both hosts have `/var/lib/sops-nix/key.txt` (framework's confirmed against `.sops.yaml` 2026-11-26) and the staged `.bootstrap/` copies are deleted
  - Rotate the password (the old hash is in git history): `passwd` on each machine, then store the new hash so fresh installs get it — `sops set secrets/common.yaml '["max-password-hash"]' "\"$(mkpasswd -m yescrypt)\""` (`secrets/common.yaml` already holds a real yescrypt hash, checked 2026-10-29; make sure it's the rotated one)
  - ~~Back up the admin key~~ — done 2026-11-26: the admin key and both workstations' restic repo passwords are in the password manager
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

- [ ] Hyprland starts, DMS greeter appears on correct monitor
- [ ] DMS bar visible with correct Gruvbox colours
- [ ] DMS launcher opens with `Super+D`
- [ ] Gruvbox Material theme applied in GTK apps
- [ ] Kitty opens with correct font and colours
- [ ] `git log` shows Gruvbox delta diffs
- [ ] `nixup` alias works
- [ ] Night light activates at sunset (Gammastep)
- [ ] Podman/Docker alias works (`d ps`)
- [ ] `nvidia-smi` shows GPU
- [ ] Steam launches, Proton available
- [ ] Syncthing UI at `localhost:8384`
- [ ] Notifications work (`notify-send test` — served by DMS)
- [ ] Apollo streaming UI at `https://localhost:47990`

---

## Up next

- [x] **Theming: Hyprland windows + DMS** — bring DMS in line with the Hyprland window styling; add transparency to DMS panels/popouts
- [x] **DMS Settings as a drop-down** instead of a window — started in 2ba26d8, still needs fixing
- [x] **Fix DMS display settings**
- [x] **Cursor sharing with the framework (lan-mouse)** — working over the tailnet (confirmed 2026-11-10)
- [x] **Fix game mode** — the side screen stayed dark after leaving gaming mode; the exit path now kicks the outputs it parked with a DPMS off/on (2026-11-26)
- [x] **Fix `Super+Q` closing every instance** — should close only the focused window
- [x] **Backblaze B2 backups** of home-desktop and framework — `hosts/common/optional/restic.nix`, live on both hosts 2026-11-26: first snapshots taken and a restore tested on each (framework: 6.7 GiB, `~/Projects` restored and diffed clean). Nightly, monitored by healthchecks.io
- [ ] **Framework dbx: confirm fwupd applies the next one.** Setup Mode ("Erase all Secure Boot Settings") wiped the dbx; it was rebuilt by hand from LVFS's `DBXUpdate-20260707-x64.cab` (291 hashes). On 2026-11-27 fwupd reads it as `20260707` (it used to say `None`), flags it updatable, and 20260707 is LVFS's newest — so the next dbx should arrive through plain `fwupdmgr update`. Unconfirmed until one is published. Either way PCR 7 changes: unlock with the passphrase once, then re-enrol the TPM (`--wipe-slot=tpm2`). Manual fallback if fwupd fails: take the `.bin` from the LVFS cab (`gcab -x`), prefix the attributes `67 00 00 00` (signed for append — `27` is refused), `sudo dd` it to `/sys/firmware/efi/efivars/dbx-d719b2cb-3d3a-4596-a3bc-dad00e67656f` in one write, reboot
- [x] **Framework BIOS 3.04** — installed 2026-11-27 via `fwupdmgr update` (capsule-on-disk, so no fwupd EFI binary to sign, and Secure Boot didn't block it). Afterwards: 03.04 running, Secure Boot still enabled with the sbctl keys, dbx untouched (291 hashes, 20260707); TPM re-enrolled with a PIN afterwards
- [x] **Obsidian off EOL Electron** — unstable's 1.15.0 renders on Electron 43 (tested 2026-11-27); the Electron 42 hold and the last `permittedInsecurePackages` entry are gone
- [ ] **Slack, Discord, WinBoat, Obsidian back to stable** once a nixpkgs release ships them on a supported Electron (moved to unstable 2026-11-27: 26.05's builds bundled EOL Electron 41/42/40/42)

## Future improvements

- [x] **Secrets management** — sops-nix (2026-09-28); key install + password rotation still pending, see Secrets above
- [ ] **GPG commit signing** — `programs.gpg` in HM + `signingkey` in flake
- [x] **Backups** — `restic` → Backblaze B2 (home-desktop + framework), live 2026-11-26
- [ ] **Pin Stylix** — tracking `master` while nixpkgs/HM are on 26.05. `release-26.05` exists now, but its Zen target lacks master's `opacityHex`, so it paints Zen solid (checked 2026-10-27; rechecked 2026-11-26: the branch has had no commits since 2026-10-09 and no open PR backports it — see `flake.nix`). Once a release branch carries it, pin that and drop the two `enableReleaseChecks = false` lines plus the kmscon/regreet `disabledModules` workaround in `hosts/common/optional/stylix.nix`
- [x] **Decide what `plymouth.nix` is for** — imported on both hosts, themed by Stylix instead of the adi1090x "spin" theme.
