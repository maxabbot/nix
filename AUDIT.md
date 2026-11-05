# Repository Audit — 2026-11-05

Scope: the whole repo on `main`, plus the running framework system. The
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
| this commit | `gaming-toggle.sh` hardcoded DP-3/DP-2; the bind now passes `monitors.lua`'s connectors. Its exit path also drew the cheat sheet over home-desktop's `wallpaperPortrait` (cave.jpg); it uses `wallpaper-redress.sh`, which picks the right one |
| this commit | The system monitor pill ran `nvtop -s` every 2 s per bar; one shared `GpuStatsService` singleton now polls, every 10 s on battery and only while a pill is shown |
| this commit | Cleanups: no-op opacity rules in `hyprland.lua`; `MOZ_ENABLE_WAYLAND` and `QT_AUTO_SCREEN_SCALE_FACTOR`; duplicate `wl-clipboard`, `enable32Bit` and `vulkan-loader`; `libva-utils` moved out of `extraPackages`; `max-jobs` left at NixOS's `"auto"` instead of a cap both hosts overrode |

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
`secrets/common.yaml` is still encrypted to the removed vm key and to the old
work-laptop key (`age16yfh…`), so either private key decrypts the current
password hash. The hash that used to be inline is in public git history, and
the rotation in TODO.md is unconfirmed. On home-desktop, where the admin key
lives: `sops updatekeys secrets/common.yaml`, then `passwd` and `sops set` the
new hash.

### 🟡 S2 — Broad pre-approvals in a public repo
`.claude/settings.json` pre-approves `Bash(python3 *)`, `Bash(curl *)`,
`Bash(nix *)` and `Bash(git *)`, which is arbitrary code and force-pushes
without a prompt for anyone opening the repo in Claude Code. Narrow it, or
move personal approvals to the gitignored `settings.local.json`. It also still
allows `waybar --version`.

### 🟡 S3 — `apollo-flake` pinned 396 days back
A network-facing service (`capSysAdmin`, open firewall) on an unmaintained
pin, and the source of the xorg warnings, which will become errors on a later
nixpkgs. Check upstream, or nixpkgs' `sunshine` module.

### 🔵 S4 — `input` group
The user is in `input` (`base.nix`), so any process they run can read raw
keystrokes. Only `autoclick` (theclicker) needs it; a uaccess udev rule for
the NuPhy's event node would do instead. Undecided.

### 🔵 S5 — Syncthing on the laptop
`openDefaultPorts` opens 22000/21027 on every interface. Traffic is
TLS-authenticated, so the risk is low; since every peer is on the tailnet,
global discovery and relays could also be turned off.

## 4. Open — bugs

### 🔵 B2 — Activation dry runs write a temp file
`dms.nix`'s `apply()` runs `$DRY_RUN_CMD jq … > "$file.hm-tmp"`; under a dry
run the redirect still writes the echoed command to `.hm-tmp`. `$DRY_RUN_CMD`
is deprecated in Home Manager, and `libreoffice.nix` already uses `run`.

## 5. Open — design

- 🟡 **No backups or snapshots.** The biggest operational gap. The btrfs
  `@home` subvolume makes btrbk or snapper cheap; restic to B2 can keep its
  credentials in sops now.
- 🟡 **Host identity inside shared code.** `dms.nix` checks
  `hostName == "framework"` twice (lock wallpaper, hidden Dolby output). Make
  them hmArgs or options.
- 🟡 **CI only evaluates.** The dozens of `--replace-fail` patches to DMS and
  its plugins only fail at local build time after a flake update. Building
  just those derivations in CI is cheap (no unfree packages).
- 🔵 **`mkHost` plumbing.** The `hostName` and `nixos-hardware` specialArgs are
  read by no module; each host restates `networking.hostName`, and
  `machineType` is given twice per host (specialArgs and hmArgs).
- 🔵 **Duplicated settings.** The location is in both `flake.nix` and
  `clight.nix` ("keep in sync"); `monitors.primary` and `kanshi.internal`
  describe framework's panel twice.
- 🔵 **Ignored defaults.** `nvidia ? false` and `kanshi ? {…}` in
  `home/max/default.nix` are never used by the module system (as
  `lan-mouse.nix`'s own comment explains).
- 🔵 **DMS layout settings go nowhere.** DMS writes
  `~/.config/hypr/dms/{layout,windowrules,cursor}.lua`, which `hyprland.lua`
  doesn't load, so its gap, rounding and border settings silently do nothing.
- 🔵 **OpenRGB on the laptop.** Package and udev rules come from
  `productivity.nix` on both hosts; `services.hardware.openrgb` on
  home-desktop alone would be the idiomatic form.
- 🔵 **`claude-code-nix` has no `follows`**, adding another nixpkgs to the lock.
- 🔵 **`wine-ge-custom` (GE-Proton8-26) is discontinued upstream**; Lutris can
  use GE-Proton through umu instead.

## 6. Open — style

- `boot = { … }` appears twice in `hosts/framework/default.nix` (statix
  doesn't flag two).
- Literal hex for delta's diff tints in `home/max/git.nix`, against the
  palette rule; add derived surfaces to `palette.nix` like `accentBg`.
- `custom.base.fancontrol` options are used by no host.
- `gaming-toggle.sh` lacks `set -euo pipefail`. Adding it needs care: its
  `grep -c` legitimately exits 1 on zero matches.
- `config/sddm/` holds a wallpaper for a removed greeter.
- Zed's default and commit-message model is still `claude-haiku-4-5`.

## 7. Open — docs

- PACKAGES.md is missing newer additions: Android Studio, WinBoat, LMMS 1.3
  and Surge XT, snowsql/dbt, the PWAs, onedriver.
- `hyprland.lua`'s header says `monitors.lua` returns only `primary`; it
  returns `secondary` too.

---

## What's in good shape

Both hosts evaluate and lint clean, and the running framework system matches
HEAD. The layering is consistent: import composition for features, one option
module, and Home Manager gated on the compositor. Nearly every host-specific
workaround carries a comment explaining why. Secrets are on sops-nix, Secure
Boot and TPM unlock are on for framework, and inputs are fresh apart from
`apollo-flake`. The confirmed bugs were all small; the larger risks are
operational: backups, the password rotation, and the dead sops recipients.
