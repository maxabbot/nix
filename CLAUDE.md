# CLAUDE.md

## Project Overview

NixOS workstation configuration using **Nix Flakes** and **Home Manager**. Declarative, reproducible, fully idempotent.

Two hosts: `home-desktop` (RTX 40-series, Hyprland, gaming) and `framework` (Framework 13 Pro, Core Ultra X7 358H / Arc Xe3 — home-desktop's stack minus NVIDIA/CUDA/fan2go and the Apollo streaming host, LUKS-encrypted root, `nixos-hardware` platform module). Both are workstations; servers live in a separate repo.

## Key Conventions

### Module system

Two patterns in use:

1. **Option-flag modules** (`modules/nixos/`) — only `base.nix` remains here. Exposes `custom.base.*` options; hosts set these to configure timezone, username, power management, etc.

2. **Import composition** (`hosts/common/optional/`) — pure config files, no options. Hosts simply import the ones they need. Each file is self-contained: it declares packages, services, and options directly.

The `hyprland` NixOS module is enabled inside `hosts/common/optional/productivity.nix`. The shared HM modules (`modules/home/`) are imported unconditionally from `home/max/default.nix`; GUI pieces gate themselves on `custom.hm.compositor != "none"` (the option's default).

### Option hierarchy (base module only)

```
custom.base.{enable, username, timezone, powerManagement, firewall, hashedPassword, hashedPasswordFile, initialPassword, sshKeys}
```

### hosts/common/optional/ files

| File | Purpose |
|---|---|
| `development.nix` | Language runtimes, dev tools, nix-ld (sshd configured but disabled; direnv is per-user in `home/max/cli.nix`) |
| `podman.nix` | Podman + Docker compat |
| `expo.nix` | Android Studio, and opens Metro's port (8081/tcp) so a phone on the LAN can load an Expo dev build (home-desktop only — Metro serves app source). Toolchains stay in per-project flakes; adb USB access comes from systemd's uaccess rules |
| `libvirt.nix` | libvirt / QEMU-KVM |
| `winboat.nix` | WinBoat (Windows 11 guest, apps over RDP) for Power BI Desktop, on Podman — asserts `podman.nix`. `chattr +C` the install folder before first-run setup (framework only) |
| `db-gui.nix` | DBeaver, Beekeeper, mycli, litecli |
| `duckdb.nix` | DuckDB |
| `cloud-tools.nix` | kubectl, helm, opentofu, AWS/Azure/GCP CLIs |
| `productivity.nix` | Hyprland, the DMS greeter (nixpkgs `dms-greeter` on greetd, in its own Lua Hyprland; hosts append monitor/cursor lines to `compositor.customConfig`; the package is patched so the launcher's `hyprctl dispatch exit` speaks Lua), PipeWire, core desktop apps, syncthing. Syncthing: flake-authoritative (`overrideDevices`/`overrideFolders`, so GUI changes revert on rebuild), one folder `~/SyncDrive` shared with the homelab (hub, tailnet) and the workstations, every peer dialled by tailnet name with discovery, relays and UPnP off (its port is tailnet-only on the laptop, like KDE Connect's); each workstation's cert/key comes from `secrets/<hostname>.yaml` when that file exists (hosts without one generate their own), so device IDs survive a reinstall. Peers/folders are mirrored in the nixos-homelab repo — change both |
| `stylix.nix` | Stylix theming (base16 Gruvbox Material, fonts, cursor) |
| `creative-apps.nix` | GIMP, Inkscape, Krita; LMMS 1.3 (upstream AppImage via `lmms-appimage` flake input, not nixpkgs' stale 1.2.2) + Surge XT for LV2 synths |
| `streaming-tools.nix` | OBS, Shotcut, RustDesk, gpu-screen-recorder |
| `google-chrome.nix` | Google Chrome |
| `onedrive.nix` | OneDrive sync via `onedriver` (FUSE, on-demand files) — run `onedriver-launcher` once per machine to add the account/mountpoint |
| `pwas.nix` | Declarative "installed" web apps (Teams, Google Chat, WhatsApp, Outlook, OneDrive, Immich — tailnet-only) via Chrome `--app` mode — `.desktop` entries generated with `makeDesktopItem`, edit the `apps` list here to add/remove. `icon` is required: a Papirus name, or a store path for apps Papirus lacks (Immich uses the pinned upstream logo) |
| `comms.nix` | Slack, Discord, Zoom |
| `nvidia.nix` | NVIDIA driver (open, RTX 40-series) |
| `cuda.nix` | CUDA / cuDNN stack |
| `gaming.nix` | Steam, Gamemode, Gamescope, Mangohud, controllers |
| `wine.nix` | Wine (WoW64 staging), winetricks, DXVK |
| `gaming-streaming.nix` | Apollo (Sunshine fork) — the streaming *host*; imports `moonlight.nix` so a host is also a client. Desktop-only: `capSysAdmin` + `openFirewall`. Carries `apollo-cve-2026-32253.patch` (client-cert validation fix Apollo merged but never released) — drop it once `apollo-flake` builds a fixed Apollo |
| `moonlight.nix` | Moonlight — the streaming *client* alone, no service and no firewall hole (framework) |
| `fan2go.nix` | Moving-average fan control (home-desktop; replaces fancontrol) |
| `lan-mouse.nix` | Software KVM between home-desktop and framework: opens its port on `tailscale0` only (asserts `tailscale.nix`), peers are pinned by tailnet IP (`ips` in `lanMouse` — lan-mouse's own resolver returns nothing for MagicDNS names). Config in `home/max/lan-mouse.nix` + `lanMouse` hmArgs; on/off from the Control Center's Lan Mouse tile (`config/dms/lanMouseTile/`) |
| `logitech.nix` | Solaar + logitech-udev-rules for Unifying/Bolt peripherals (MX Ergo S); also owns the Bolt receiver's wakeup-disable udev rule, so it follows the receiver between machines. Tray unit + `config/solaar/rules.yaml` wiring in `modules/home/wm/hyprland.nix` (Solaar owns `config.yaml`, so only `rules.yaml` is declared). Pairing and key diversion are per-machine device state — see the file header |
| `keyboards.nix` | Configurator/flashing access for the programmable keyboards: QMK udev rules (Sofle bootloader/DFU), NuPhy Air75 V3 hidraw rule, Vial hidraw rule (home-desktop, framework) |
| `clight.nix` | Ambient-light auto-brightness for the internal panel (framework). Backlight module only — gamma/dimmer/keyboard/screen are off (gammastep and hypridle own those); DPMS stays on with `-1` (never) timeouts, because with dimmer *and* DPMS off Clight force-disables inhibit and the tile's Pause stops working; fades off (clightd 5.9 drops to raw 0 when fading to the current level); curves floored at 3% so darkness never blacks the panel; clightd built without DDC (overlay) so docked monitors stay with the DMS slider; the package's XDG autostart entry (an unconfigured second Clight that blanks the screen) is hidden; never order clight after hypridle (ordering cycle drops clight's start). Its tile is DMS's first-party `dankClight` plugin, installed wherever `services.clight` is on, patched so an icon tap toggles pause from Clight's live state |
| `tailscale.nix` | Tailscale client (reaches the Tailscale-only services in the servers repo) + systemd-resolved for MagicDNS. Log in once per machine with `sudo tailscale up --operator=max` |
| `sops.nix` | sops-nix secrets (both hosts): decrypts `secrets/*.yaml` with the host age key at `/var/lib/sops-nix/key.txt`; sets `custom.base.hashedPasswordFile`. Recipients in `.sops.yaml`; admin key shared with the homelab repo. Per-host files `secrets/home-desktop.yaml` and `secrets/framework.yaml` (Syncthing identity) are decryptable by admin + that host only |
| `plymouth.nix` | Boot splash (both hosts) — Gruvbox bg + spinning snowflake; also themes the framework LUKS prompt. Own script theme (`config/plymouth/`, Stylix's plymouth target disabled): it re-centres every frame, since the displays change mid-splash (simpledrm → real KMS driver) |
| `limine.nix` | Limine boot manager, Gruvbox-themed menu + wallpaper (both hosts; replaces systemd-boot — for Secure Boot use `boot.loader.limine.secureBoot`) |
| `btrfs.nix` | The btrfs-with-`@nix` disko layout (both hosts): systemd-initrd retry for `initrd-find-nixos-closure` across btrfs's first-mount window, plus a monthly `autoScrub` |

### Home Manager

- Wired as a NixOS module via `home-manager.nixosModules.home-manager`.
- `mkHost` sets `networking.hostName`, passes `machineType` (`"desktop"` / `"laptop"`) as a module argument to both NixOS and HM modules, and passes `hmArgs` to `home-manager.extraSpecialArgs`. **Do not** add `extraSpecialArgs` inside a host's `default.nix` — this conflicts with `mkHost` and is a recurring footgun.
- Shared args (git name/email) live in `sharedHmArgs` in `flake.nix`; per-host args override via `sharedHmArgs // hmArgs`.
- `home/max/` is split into feature files: `default.nix` (entry), `claude.nix` (Claude Code: the package + `sox` for voice mode, and its theme + status line, merged into `~/.claude/settings.json` on activation — Claude Code rewrites that file, so it isn't a symlink, and an in-app `/theme` change reverts on rebuild; plus `claude-account` (`pkgs/claude-account/`), which saves logins (`.credentials.json` + `~/.claude.json`'s `oauthAccount`) under `~/.claude/accounts/` and swaps between them with settings/memory shared — the claudeUsage widget's popout drives it), `git.nix`, `cli.nix`, `desktop.nix`, `lan-mouse.nix`, `libreoffice.nix`, `packages.nix`, `terminal-toys.nix`.
- Setting `compositor = "none"` skips Hyprland and the DMS shell entirely via `mkIf`.
- The desktop shell is DMS (DankMaterialShell): `modules/home/wm/dms.nix` (package patches, declared settings/bars, `shell-dms.service`) and `modules/home/wm/dms-plugins.nix`; design notes in `docs/SHELLS.md`.

### Rebuild

```bash
nixup   # nh os switch /etc/nixos  (auto-detects host by hostname)
# or explicitly:
sudo nixos-rebuild switch --flake /etc/nixos#<host>
```

### Shell scripts

All `*.sh` linted with shellcheck; quote properly. Use `bash` and prefer `set -euo pipefail` for new scripts (long-running event loops in `config/hypr-scripts/` intentionally omit it so one failed poll doesn't kill the loop).

### Machine-local state (not in Nix)

- **Obsidian vault:** `~/Obsidian` (moved from `~/Documents/Personal` on 2026-09-30), synced by Obsidian Sync — not Syncthing, so never add it as a Syncthing folder. Only the `obsidian` package is declared (`productivity.nix`); the vault's location lives in `~/.config/obsidian/obsidian.json`, which Obsidian rewrites itself, so it is deliberately not managed by Home Manager. On a fresh machine: "Open folder as vault", then log in to Sync and pick the existing remote vault.

## Adding things

| Want to add… | Where |
|---|---|
| System-wide package (all desktop hosts) | `environment.systemPackages` in the relevant `hosts/common/optional/*.nix` |
| System-wide package (one host only) | `environment.systemPackages` in `hosts/<name>/default.nix` |
| New optional feature | New file in `hosts/common/optional/`, import in the hosts that need it |
| User package | `home.packages` in `home/max/packages.nix` |
| New HM feature | New file in `home/max/`, add to imports in `home/max/default.nix` |
| Plain-text dotfile | `config/<app>/...` + wire via `xdg.configFile` |
| Hypr script | `config/hypr-scripts/` — deployed as a store symlink to `~/.config/hypr/scripts/`, so edits need `git add` + `nixup` to take effect |
| DMS widget / plugin QML | `config/dms/` — installed into the DMS package or a plugin by `modules/home/wm/dms.nix` / `dms-plugins.nix`; needs `nixup` + `systemctl --user restart shell-dms` |
| Package not in nixpkgs | Add derivation under `pkgs/<name>/`, expose via `callPackage` in `overlays/default.nix` |

## Security

- Never commit credentials — `github_pat`, `*.iso` are gitignored.
- Secrets go in sops (`hosts/common/optional/sops.nix`, `secrets/*.yaml`, recipients in `.sops.yaml`) — never a literal in a `.nix` file, which lands in git and the world-readable store. Edit with `sops secrets/common.yaml` on home-desktop; a new per-host file needs its own `.sops.yaml` rule (above the admin-only catch-all) so it isn't encrypted to every host. The user password hash is `max-password-hash`; with `mutableUsers` on it only applies at user creation, so existing machines change password with `passwd`. The old inline hash is still in git history — treat that password as exposed.
- `sshKeys = [ ]` is empty by default; populate before enabling `services.openssh` for remote login.
- Secure boot: on the Limine hosts, set `boot.loader.limine.secureBoot.enable = true` after running `sbctl create-keys` + `sbctl enroll-keys` (see the `limine.nix` header).

## Theme

**Gruvbox Material Dark** across all apps. `config/stylix/palette.nix` is the single source of truth for colour values: Stylix (`hosts/common/optional/stylix.nix`) derives its base16 scheme from it and owns GTK/Qt/fonts/cursor; apps with richer needs (kitty, tmux, Starship, cava, spotify-player, limine, plymouth) have their Stylix targets disabled and interpolate the palette in their Nix modules instead. Plain-text configs (`shortcuts.css`, `hyprland.lua`, `config/plymouth/*`, plus `config/dms/gruvbox-material.json` for the DMS shell and `config/lock/gruvbox-rainbow-framework.svg`, framework's lock-screen background — it and the rainbow Nix wallpaper (Limine, the DMS lock) are rasterised by `pkgs/gruvbox-wallpapers` — and `config/claude/statusline.sh`, Claude Code's status line) are templates: `config/stylix/palette-subst.nix` renders their `@name@` / `@name-hex@` / `@name-rgb@` placeholders from the palette at build time — write placeholders there, never literal hex. Only `config/fastfetch/config.jsonc` is untemplated (named ANSI colours, nothing to sync).

Two `@token@`s are *not* palette placeholders. `docs/SHORTCUTS.md` carries `@host@`, substituted with the hostname in `modules/home/wm/hyprland.nix` (via `osConfig`) so the cheat sheet names the machine it's deployed on — don't route that file through `palette-subst.nix`. `config/claude/statusline.sh` carries `@dirSubstitutions@`, which `home/max/claude.nix` fills (after the palette pass) from Starship's `directory.substitutions`, so the status line's folder icons follow the prompt's.
