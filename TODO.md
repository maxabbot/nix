# TODO — Before First Use

Things to do before running `nixos-rebuild switch` for the first time.

---

## 1. Generate hardware configurations (required per machine)

On each target machine, boot the NixOS ISO, partition, mount at `/mnt`, then run:

```bash
sudo nixos-generate-config --root /mnt
```

Copy the generated file into the right host directory:

```bash
# Home desktop
cp /mnt/etc/nixos/hardware-configuration.nix hosts/home-desktop/hardware-configuration.nix

# Work laptop
cp /mnt/etc/nixos/hardware-configuration.nix hosts/work-laptop/hardware-configuration.nix

# Minimal
cp /mnt/etc/nixos/hardware-configuration.nix hosts/minimal/hardware-configuration.nix
```

The placeholder files contain a stub layout — replace them entirely.

---

## 3. Set your monitor configuration

Edit `hosts/home-desktop/default.nix` and update `monitors.primary` (and optionally `secondary`).
Format: `<output>,<resolution>@<hz>,<x>x<y>,<scale>`

```nix
monitors = {
  primary   = "DP-1,2560x1440@144,0x0,1";
  secondary = "HDMI-A-1,1920x1080@60,2560x0,1";  # or null
};
```

Find your output names by running `hyprctl monitors` or `swaymsg -t get_outputs` after first boot
with a default config, or from the `nixos-generate-config` output.

Also update the `clock.timezone` in `modules/home/wm/waybar.nix` to your timezone.

---

## 6. Packages not yet in nixpkgs (may need overlays)

Check these at first build:

- `gruvbox-material-gtk-theme` → check `pkgs.gruvbox-material-gtk-theme` exists in nixos-unstable; `theme.nix` falls back to `pkgs.gruvbox-dark-gtk`
- `apollo-bin` (streaming server) → needs custom derivation in `pkgs/` if wanted
- `zen-browser` → check `pkgs.zen-browser` (may need the `rycee/nur-expressions` overlay)
- `gpu-screen-recorder` → check current nixpkgs name
- `latencyflex` → not confirmed in nixpkgs; remove from `gaming.nix` if build fails
- `itch` (`pkgs.itch`) → verify package name (sometimes `itch-app`)

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
# Follow docs/guides/arch-install.md
```

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
