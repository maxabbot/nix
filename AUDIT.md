# Repository Audit — 2026-11-05 (security pass 2026-11-27)

**2026-11-27:** a security-only pass over both hosts, read from the running
framework system and `nix eval` of both configurations (the live firewall and
`/etc/shadow` need root and were not read). Its fixes are the S6–S9 rows in §1;
S1 is restated and S10–S11 are new in §3. S4 is fixed.

Scope of the 2026-11-05 audit: the whole repo on `main`, plus the running framework system. The
2026-07-07 audit is in git history; its open items (secrets, xorg warnings) are
carried forward below where they still apply. During this audit work-laptop
(51b1c7e) and the vm host (20cb6c0) were removed, so two hosts remain:
home-desktop and framework.

Severity key: 🔴 fix soon · 🟡 worth fixing · 🔵 suggestion / cleanup

## Tooling results

- `nix flake check --no-build` passes for both hosts. The only warnings are
  the nine *"The xorg package set has been deprecated"* ones, all from
  `apollo-flake` on home-desktop.
- statix, deadnix, shellcheck (every script, `config/scripts/autoclick`
  included) and nixfmt-tree are clean. The NixOS and Home Manager `warnings`
  lists are empty on both hosts.
- framework's toplevel built from HEAD was identical to the running system.
- Every palette `@token@` in the templates resolves; every MIME default names
  a desktop file that exists.
- No failed system or user units. The 91 quickshell coredumps on 2026-11-05
  12:48–12:54 came from a nested-Hyprland greeter preview, not from config.

---

## 1. Fixed in this pass

| Commit | Fix |
|---|---|
| 7eeda73 | delta was never git's pager: HM's `programs.delta.enableGitIntegration` defaults to false |
| 7eeda73 | tmux `Prefix+f` ran the sessionizer through `run-shell`, which has no TTY, so fzf couldn't start; it uses `display-popup` now |
| 7eeda73 | `alias cc="cargo check"` shadowed the C compiler; now `ck` |
| 7eeda73 | Zed's nil formatter called a bare `nixfmt`, which is only on PATH in the devShell |
| 96cc62b | direnv was hooked twice (system `programs.direnv` and HM); only HM's remains |
| 96cc62b | `hyprland.lua` still loaded DMS's `outputs.lua`, superseded by the live-apply patch; any file DMS wrote would have overridden `monitors.lua` on reload |
| 96cc62b | Nix Monitor's icon named "FiraCode Nerd Font", which isn't installed |
| 96cc62b | `resume-probe.sh` watched hyprlock, removed in 2249eb0; it now records logind's LockedHint and the DMS lock's quickshell process |
| 02265e7 | framework opened KDE Connect (1714-1764) and Steam Remote Play on every network; KDE Connect is tailnet-only and Remote Play closed on the laptop (`machineType`) |
| b475523 | Docs drift: SHORTCUTS (`z`, scratchpad, lid), PACKAGES (ncspot, sessionizer key), SHELLS (`wake-monitors.sh`), config-comparison (secrets, Secure Boot), TODO (SDDM), README, and the stale cross-references in `logitech.nix` and `lan-mouse.nix` |
| 2668c0e | `gaming-toggle.sh` hardcoded DP-3/DP-2; the bind now passes `monitors.lua`'s connectors. Its exit path also drew the cheat sheet over home-desktop's `wallpaperPortrait` (cave.jpg); it uses `wallpaper-redress.sh`, which picks the right one |
| 2668c0e | The system monitor pill ran `nvtop -s` every 2 s per bar; one shared `GpuStatsService` singleton now polls, every 10 s on battery and only while a pill is shown |
| 2668c0e | Cleanups: no-op opacity rules in `hyprland.lua`; `MOZ_ENABLE_WAYLAND` and `QT_AUTO_SCREEN_SCALE_FACTOR`; duplicate `wl-clipboard`, `enable32Bit` and `vulkan-loader`; `libva-utils` moved out of `extraPackages`; `max-jobs` left at NixOS's `"auto"` instead of a cap both hosts overrode |
| ea585ed | CI only evaluated, so the `--replace-fail` patches to DMS, its greeter and plugins broke only at local build time; flake `checks` now hold those 11 derivations and CI builds them (`nix flake check` without `--no-build`) whenever a file they're built from changed; other pushes only evaluate. CI's shellcheck also covers `config/scripts/autoclick` now |
| 6c3e2ce | CI builds the checks only when a file they're built from changed; other pushes evaluate only |
| ce41270 | Output-neutral refactor (both toplevels byte-identical): `dms.nix`'s `hostName == "framework"` checks became the `lockWallpaper` hmArg and `custom.hm.dms.hiddenOutputs`; `mkHost` sets `networking.hostName` and forwards `machineType`, dropping the unused specialArgs; one `location` in `base.nix` for Clight and gammastep; kanshi's internal panel defaults from `monitors.primary`; ignored `? defaults` and the unused `custom.base.fancontrol` removed |
| 9e633e2 | OpenRGB on home-desktop only; `claude-code-nix` follows `nixpkgs-unstable` (one fewer nixpkgs in the lock) |
| 20b1f9f | HM activation uses `run` instead of the deprecated `$DRY_RUN_CMD`, and a dry run no longer writes `.hm-tmp` files (B2). Style: framework's second `boot` block, delta's literal hex (now palette `diffAddBg`/`diffDelBg`), `config/sddm/` (wallpaper moved to `config/wallpapers/`), `hyprland.lua`'s header. Docs: PACKAGES.md's missing apps, SHELLS.md on DMS's layout pages |
| d84e6c4 | DMS's Hyprland Layout Overrides wrote an unloaded `layout.lua` and ran `hyprctl reload` on every regeneration (13 on 2026-11-05), dropping live session state. Explicit overrides now apply live over `hyprctl eval`; Auto/Off keep `hyprland.lua`'s values, and with none set DMS no longer reloads Hyprland. The unusable Xray toggles are hidden |
| 2cd7c44 | DMS's cursor page wrote an unloaded `cursor.lua` (then reloaded Hyprland); it now applies live like the layout page. Its Window Rules page wrote `windowrules.lua` that nothing loaded; `hyprland.lua` now loads it after its own rules (DMS reports them active) |
| 580f364 | The discontinued Wine-GE runner (`wine-ge-custom`, GE-Proton8-26) is gone; Lutris gets nixpkgs' GE-Proton (the Steam build) as a wine version, run through `umu-launcher` |
| 091eabe | S3: Apollo (pinned 0.4.7-alpha.1, its latest release) had CVE-2026-32253, a client-certificate validation bypass that let an untrusted client pass as paired. Apollo merged the fix to master but never released it; `gaming-streaming.nix` now applies it as a patch |
| 14f28ff | S5: Syncthing's port is tailnet-only on the laptop (open on home-desktop's LAN), the workstations dial each other by tailnet name, and global/local discovery, relays and UPnP router forwarding are off |
| 731ca18 | Style: `gaming-toggle.sh` runs with `set -uo pipefail` (not `-e`, on purpose — see its header), tested on both paths against stub tools. Zed's `claude-haiku-4-5` is the newest Haiku Zed offers, so no change |
| (2026-11-05) | S2: `.claude/settings.json` (public repo) no longer pre-approves `git *`, `nix *`, `python3 *`, `curl *` or `gh api *`; read-only `git`, `nix` and `gh run` subcommands replace them. The broad rules live in the gitignored `.claude/settings.local.json` on machines that want them |
| 2026-11-27 | S6 (with S4): the user was in three groups that each bypassed sudo's password. `podman` owns `/run/podman/podman.sock`, the rootful socket (`-v /:/host` → root); every container here is rootless, WinBoat's included, and the rootful store was empty. `libvirtd` is full `qemu:///system`, which can attach the raw disk to a VM; virt-manager now asks polkit for the admin password. `input` (S4) read every keystroke on every keyboard regardless of focus. All three are gone from `base.nix`, plus `kvm` (`/dev/kvm` is 0666). The NuPhy configurator's hidraw rule is uaccess now (`keyboards.nix`, a `59-nuphy.rules` package like Vial's), and `autoclick` runs theclicker through sudo |
| 2026-11-27 | S7: the Chrome Cast rule (`google-chrome.nix`) accepted UDP by *source* port 1900/5353 from any private address to **any** port, ahead of the final reject. A sender picks its own source port, so on any café/office network framework's tailnet-only UDP services (KDE Connect 1716, Syncthing 22000, lan-mouse 4242, LLMNR 5355) were reachable. Now limited to `--dport 32768:60999`, Chrome's ephemeral range |
| 2026-11-27 | S8: systemd-resolved answered and queried LLMNR on every link (spoofable on public wifi, Responder-style); `LLMNR = false` in `tailscale.nix`. MagicDNS and avahi cover name resolution |
| 2026-11-27 | S9: `.claude/settings.json` pre-approved `hyprctl *`, and `hyprctl dispatch exec` runs any command, skipping the permission prompt entirely. Narrowed to read-only subcommands (`monitors`, `clients`, `devices`, `getoption`, …, with and without `-j`); `nh os *` (switch to any flake) narrowed to `nh os build *`. `nixup *` stays — it switches this repo only and still needs sudo |

## 2. Verified on hardware — not bugs

Read from code and logs these looked plausible. On 2026-11-05 the user
confirmed all three work:

- Fingerprint unlock on the DMS lock screen. fprintd's "Device was already
  claimed" at each lock is noise.
- Nix Monitor's rebuild button (`nh os switch` with no terminal).
- The docked kanshi layout survives `hyprctl reload`, so the reload fallbacks
  in `dpms.sh` and `gaming-toggle.sh` need no `kanshictl reload` after them.

---

## 3. Open — security

### 🔴 S1 — Dead recipients and an unrotated password
Still open on 2026-11-27. `.sops.yaml` is clean, but `secrets/common.yaml`
hasn't been touched since 2026-09-28: it is still encrypted to the removed vm
key (`age1l4gy…`) and the old work-laptop key (`age16yfh…`), so either private
key decrypts the password hash, and that hash is therefore not a rotated one.
The old inline hash (`$y$j9T$2U13…`) is in the history of a **public** GitHub
repo, open to offline cracking. On home-desktop, where the admin key lives:
`sops updatekeys secrets/common.yaml`, `passwd` on both machines, then
`sops set` the new hash (command in TODO.md). With S6 fixed, the password is
again what stands between a user-level compromise and root.

### 🟡 S10 — home-desktop has no disk encryption or Secure Boot
It holds the most valuable keys in either repo: the admin age key
(`~/.config/sops/age/keys.txt`, which decrypts every secret here *and* in
nixos-homelab), the homelab's B2 prune key (`restic-maintenance.nix`), both
restic passwords and its Syncthing identity — all readable by anyone who boots
the machine from USB or takes the disk. Options: LUKS + TPM2 + Secure Boot like
framework at the next reinstall (disko can't add LUKS in place), or move the
admin key onto a hardware token now (age-plugin-yubikey), which also keeps it
away from user-level processes.

### 🟡 S11 — B2 versioning may not stop a key holder
Both restic files rely on "a delete is a hide that lives 30 days". That holds
for restic's own deletes, which name no version. But a B2 key with
`deleteFiles` can delete a *specific version* (S3 `DeleteObject` with
`versionId`), which is permanent, and that is what an attacker with the key
would do. Unverified against B2 — test on a scratch bucket. If it holds, the
real guard is Object Lock with a default retention period; the comments'
claim that Object Lock "breaks restic outright" is worth re-testing, since a
delete without a version ID on a locked bucket only adds a hide marker.

## 4. Open — bugs

None known.

## 5. Open — design

- ~~🟡 **No backups or snapshots.**~~ restic to B2 is live on both hosts
  (2026-11-26, `restic.nix`); local btrfs snapshots are still absent.
- 🔵 framework sends nearby wifi BSSIDs to BeaconDB every 10 minutes
  (`geoclue-iwd.nix`). Intended, and a privacy trade rather than a security
  hole.

## 6. Open — style

None known.

## 7. Open — docs

None known.

---

## What's in good shape

Both hosts evaluate and lint clean, and CI builds the patched DMS packages
whenever something they're built from changes. The layering is consistent: import composition for features, one option
module, and Home Manager gated on the compositor. Nearly every host-specific
workaround carries a comment explaining why. Secrets are on sops-nix, Secure
Boot and TPM unlock (with a PIN) are on for framework, sshd is off on both
hosts, framework's peer services are tailnet-only, `trusted-users` is root
alone, CUPS and the Syncthing GUI listen on localhost only, and the restic
units are sandboxed. The only secret ever committed in plaintext is the one
password hash (S1). Inputs are fresh; `apollo-flake`
tracks Apollo's last release, patched for its one known CVE. The confirmed bugs were all small; the larger risks left are
operational: the password rotation and dead sops recipients (S1), and an
unencrypted home-desktop holding the admin key (S10).
