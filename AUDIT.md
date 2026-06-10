# Repository Audit — 2026-06-10

Scope: full repo (`flake.nix`, `modules/`, `hosts/`, `home/`, `config/`, `overlays/`, `pkgs/`, docs).

Tooling results: `nix flake check --no-build` **passes** for all four hosts. `deadnix` clean.
`shellcheck` clean on all scripts. `statix` reports one warning (see R1). Two evaluation
warnings surfaced (B4, B5).

Severity key: 🔴 fix soon · 🟡 worth fixing · 🔵 suggestion / cleanup

> **Remediation status (same day):** B1–B4, B6–B8, S2–S4, D1–D5, R1–R10 fixed (R10's
> `caching.sh`/`QS_DIR` sub-item turned out stale — the script now uses it). Doc drift
> (section 4) fixed in CLAUDE.md/TODO.md/nix comments. `nix flake check` re-verified clean,
> statix/deadnix clean, kanshi deprecation warning gone, and `minimal` verified GUI-free
> (kitty/Zed/VSCode/GTK all evaluate to disabled). Items are annotated ✅ below.
> **Still open:** S1 (secrets — needs agenix/sops-nix decision + password rotation),
> B5 (xorg rename warnings from a flake input), and section 6 suggestions
> (CI, pre-commit hook, nixos-hardware, backups, `programs.nh.clean`).

---

## 1. Bugs / broken behaviour

### 🔴 B1 — ✅ FIXED — `Super+E` launches a file manager that isn't installed
`config/hypr/hyprland.lua:172` binds `Super+E` to `nautilus`, but no module installs
Nautilus — the installed file manager is Thunar (`hosts/common/optional/productivity.nix:119`).
The keybind silently does nothing. Change the bind to `thunar` (or add Nautilus).

### 🔴 B2 — ✅ FIXED (script deleted) — `lock.sh` references a QML file that doesn't exist
`config/hypr-scripts/lock.sh` launches `quickshell -p …/quickshell/Lock.qml`, but there is no
`Lock.qml` in `config/hypr-scripts/quickshell/`. The script is also referenced nowhere
(locking goes through `hyprlock` directly, `hyprland.lua:219` and hypridle). Delete or fix.

### 🟡 B3 — ✅ FIXED — `qs_manager.sh` silently deletes users' wallpaper files
`config/hypr-scripts/qs_manager.sh` (wallpaper prep, ~line 120): any `.webp` in the wallpaper
directory is converted to `.jpg` and the **original file is deleted**
(`magick "$img" "$new_img" && rm -f "$img"`). A thumbnail-cache routine should never mutate
the source directory. Convert into the thumb dir instead and leave the original alone.

### 🟡 B4 — ✅ FIXED — kanshi uses a deprecated option (will break on a future HM bump)
Evaluating `work-laptop` warns: *"kanshi.profiles option is deprecated. Use kanshi.settings
instead."* `modules/home/wm/kanshi.nix:83` still uses `services.kanshi.profiles`. Migrate to
`settings` before the alias is removed.

### 🟡 B5 — xorg deprecation warnings on home-desktop
`nixosConfigurations.home-desktop` evaluation emits ~9 warnings like *"'xorg.libX11' has been
renamed to 'libx11'"*. These come from a flake input or local derivation (most likely
`apollo-flake` or another pinned input), not your own modules — worth chasing upstream or
re-pinning, since they'll become hard errors eventually.

### 🟡 B6 — ✅ FIXED — Waybar shows a dead GPU module in the VM
`modules/home/wm/waybar.nix` adds `custom/gpu` (an `nvidia-smi` poller) whenever
`machineType == "desktop"`. The `vm` host is `machineType = "desktop"` but has no NVIDIA GPU,
so the bar permanently shows `GPU ?% ?°C`. Gate on the `nvidia` hmArg (already available as
`cfg.nvidia`) instead of `machineType`.

### 🟡 B7 — ✅ FIXED (systemctl + gamescope size now read from the focused monitor) — `gaming-toggle.sh` fights the Waybar systemd service
Waybar runs as a systemd user service (`programs.waybar.systemd.enable = true`), but
`config/hypr-scripts/gaming-toggle.sh` does `pkill -f waybar` and later restarts it with a raw
`waybar &`. That leaves the unit in a failed state and the relaunched process unmanaged. Use
`systemctl --user stop/start waybar.service`. Same file also hardcodes the primary monitor
(`gamescope -W 2560 -H 1440 -r 165`) — fine for one machine, but it's a shared script imported
by every Hyprland host.

### 🔵 B8 — ✅ FIXED (python3 check, env-var path passing, `--no-sandbox` dropped) — `shortcuts-wallpaper.sh` doesn't check for `python3` and interpolates paths into Python
The dependency loop checks `pandoc`, `google-chrome-stable`, `awww` but then calls `python3`
three times (script would die under `set -e` if missing — add it to the check). The Python
snippets interpolate `$SRC` directly into source code; harmless today, brittle if paths ever
contain quotes. Also: `--no-sandbox` for headless Chrome is unnecessary here.

---

## 2. Security

### 🔴 S1 — Password hash committed to the repo (same hash on all four hosts)
Every host sets the identical yescrypt hash in `custom.base.hashedPassword`
(`hosts/{home-desktop,work-laptop,vm,minimal}/default.nix`). The repo has a LICENSE and looks
publish-ready — a committed hash invites offline cracking, and one crack opens all machines
(all wheel users). This is already on `TODO.md`; bumping the priority: move to agenix/sops-nix
(`users.users.<n>.hashedPasswordFile`), and rotate the password once secrets land since the
current hash is in git history.

### 🟡 S2 — ✅ FIXED — World-writable hidraw device for the NuPhy keyboard
`hosts/home-desktop/default.nix:288` used `MODE="0666"` — any local user/process could talk
to the keyboard's HID interface. Now `MODE="0660", GROUP="input"`. (`TAG+="uaccess"` was not
an option: `extraRules` becomes `99-local.rules`, which runs after `73-seat-late.rules` has
already processed uaccess tags.)

### 🟡 S3 — ✅ FIXED (deliberate-trade-off comment added) — Zed agent terminal auto-allow
`modules/home/editor.nix:156` sets agent `tool_permissions.tools.terminal.default = "allow"`,
letting the editor's AI agent run shell commands without prompting. Deliberate trade-off
perhaps, but worth an explicit comment so it isn't cargo-culted later.

### 🔵 S4 — ✅ FIXED (package dropped) — clamav is installed but never runs
`modules/nixos/base.nix:211` ships the `clamav` package without `services.clamav.daemon` or
`.updater`. A scanner with no freshclam updates and no service provides no protection — either
enable the services or drop the package.

---

## 3. Dead code

### 🔴 D1 — ✅ FIXED — Orphaned scripts in `config/hypr-scripts/` (~750 lines)
These are symlinked into `~/.config/hypr/scripts/` but referenced by **nothing** (checked
`hyprland.lua`, all QML, all nix modules, all other scripts):

| Script | Status | Notes |
|---|---|---|
| `lock.sh` | ✅ deleted | Launched a nonexistent `Lock.qml` (B2) |
| `workspaces.sh` (107) | ✅ deleted | Superseded: `Workspaces.qml` reads `Hyprland.workspaces` natively |
| `volume_listener.sh` (40) | ✅ deleted | OSD is driven by `swayosd` binds in `hyprland.lua` instead |
| `exit.sh` | ✅ deleted | Pre-UWSM logout helper; wlogout's logout action now uses `uwsm stop` (the canonical clean logout), making it redundant |
| `reload.sh` | ✅ deleted | Unreferenced; also called a nonexistent `forceReload` IPC function |
| `screenshot.sh` (352 lines) | being revived | `satty`/`zbar` now installed and a Quickshell screenshot UI is in progress — no longer dead code |
| `settings_watcher.sh` (147) | ✅ deleted | Referenced `weather.sh`, `templates/`, `install.sh` artifacts and a `calendar/.env` that never existed in this repo — imported from another dotfiles project |

### 🟡 D2 — ✅ FIXED (references removed with the section-4 doc-drift pass) — `deploy.sh` is referenced but doesn't exist
`CLAUDE.md`, `TODO.md`, `hosts/common/optional/development.nix` (comment) and
`hosts/minimal/default.nix` (comment) all mention `deploy.sh`. There is no such file — the
install path documented in `TODO.md` is nixos-anywhere. Update the references.

### 🟡 D3 — ✅ FIXED (root copy deleted; everything pointed at `docs/`) — Stale duplicate `SHORTCUTS.md` at repo root
Root `SHORTCUTS.md` and `docs/SHORTCUTS.md` differ; everything that matters
(`modules/home/wm/hyprland.nix:156`, the cheat-sheet wallpaper, `PACKAGES.md`) points at
`docs/SHORTCUTS.md`. The root copy will drift further — delete or symlink it.

### 🔵 D4 — ✅ FIXED (deleted; CLAUDE.md row updated to match practice) — `pkgs/default.nix` is unused boilerplate
`overlays/default.nix` calls `callPackage ../pkgs/wine-ge-custom` directly; nothing imports
`pkgs/default.nix`. Either wire it up as the aggregation point CLAUDE.md describes, or delete
it and fix the CLAUDE.md "Adding things" row.

### 🔵 D5 — ✅ FIXED (removed) — `sharedHmArgs.git.signingkey = ""` is never consumed
`flake.nix:97` defines it; `home/max/git.nix` never reads it. Remove until GPG signing
(TODO.md item) is actually implemented.

---

## 4. Documentation drift — ✅ FIXED (CLAUDE.md, TODO.md, and nix comments updated)

| Doc claim | Reality |
|---|---|
| CLAUDE.md: *"All `*.sh` … use `set -euo pipefail`"* | Only 2 of 13 scripts do (`clipboard-fuzzel.sh`, `shortcuts-wallpaper.sh`) |
| CLAUDE.md Security: *"ships `initialPassword = "123"`"* | All hosts now use `hashedPassword` (see S1) |
| CLAUDE.md: *"Package not in nixpkgs → add to `pkgs/default.nix`"* | That file is dead (D4) |
| CLAUDE.md / TODO.md: `deploy.sh` workflow | File doesn't exist (D2) |
| TODO.md post-install: *"Swaync notifications work"* | swaync was replaced by the Quickshell notification server (`Shell.qml`) |
| TODO.md: *"Replace `initialPassword = "123"`"* | Already replaced; item should now read "move hash out of git" |

Also: 16 of the last 30 commit messages are single letters (`l`, `m`, `v`, `d`, `c`). With a
repo this well-commented, the history is the one place you can't reconstruct intent — even one
short sentence per commit would pay for itself.

---

## 5. Refactoring opportunities

### 🟡 R1 — ✅ FIXED — statix: repeated attribute keys in `hosts/home-desktop/default.nix`
`services.*` is assigned at lines 58, 251, 259 and `boot` keys similarly. Merge into single
`services = { … }` / `boot = { … }` blocks (statix W20).

### 🟡 R2 — ✅ FIXED (duplicate `environment.variables` removed; env.lua copy kept intentionally — applies before session env) — NVIDIA env vars defined three times
`__GLX_VENDOR_LIBRARY_NAME`, `GBM_BACKEND`, `LIBVA_DRIVER_NAME` appear in
`nvidia.nix` `environment.variables` **and** `environment.sessionVariables`, and again
(minus GBM) in the generated Hyprland `env.lua` (`modules/home/wm/hyprland.nix:69`).
`sessionVariables` alone covers login sessions; keep one source of truth.

### 🟡 R3 — ✅ FIXED (obs deduped; vulkan dev tools out of nvidia.nix; wine packages moved into wine.nix) — Package duplication across optional modules
- `obs-studio` in both `streaming-tools.nix` and `gaming-streaming.nix` (both imported by home-desktop).
- `vulkan-tools`, `vulkan-loader`, `vulkan-validation-layers` in both `nvidia.nix` and `gaming.nix`.
- Wine is split oddly: `gaming.nix` carries `wineWow64Packages.staging` + `winetricks`, while
  `wine.nix` contains only `dxvk`. Either fold `wine.nix` into `gaming.nix` or move the wine
  packages into `wine.nix` so the file names mean what they say.

### 🟡 R4 — ✅ FIXED (apps/editor/theme gated on compositor; base.nix bluetooth/blueman/printing still unconditional) — `minimal` isn't minimal: HM installs the GUI stack on the headless host
`modules/home/{apps,editor,theme}.nix` have no `compositor`/`machineType` gate, so the
`minimal` host gets Zed, VSCode, kitty, mpv, zathura, fuzzel, freetube, GTK theming, etc.
CLAUDE.md's claim that `compositor = "none"` "skips Hyprland and Waybar" is true but those are
the only things skipped. Gate these modules (e.g. `lib.mkIf (cfg.compositor != "none")`) or
split `modules/home/default.nix` into cli/gui import lists. Similarly, `base.nix` enables
bluetooth + blueman + printing on the server profile.

### 🟡 R5 — ✅ FIXED — `productivity.nix` hardcodes the username
`services.syncthing.{user,dataDir,configDir}` hardcode `max`/`/home/max` while everything else
flows through `custom.base.username`. Use `config.custom.base.username` (the module already
receives `config`).

### 🟡 R6 — ✅ FIXED (single `python3.withPackages` interpreter) — Global Python site-packages in `development.nix`
`python3Packages.{matplotlib,numpy,pandas,scipy,scikit-learn,pip,virtualenv}` as individual
`systemPackages` is the classic NixOS footgun — separate store paths, no shared `PYTHONPATH`,
`pip` can't install into any of it. Either `python3.withPackages (ps: [ ps.numpy … ])` for one
coherent interpreter, or drop them and rely on the already-present `uv` + direnv per-project
flow.

### 🔵 R7 — ✅ FIXED (base only enables; all settings in the host file) — TLP configured in two places for work-laptop
`custom.base.powerManagement = "tlp"` makes `base.nix` enable TLP with
`TLP_DEFAULT_MODE = "AC"`, then `hosts/work-laptop/default.nix:32` re-enables it with its own
settings. It merges, but the split is confusing — pick one home (host file is the natural one;
or extend the base option with a `settings` passthrough).

### 🔵 R8 — ✅ FIXED (defaults removed from all hosts) — Redundant per-host defaults
Every host repeats `firewall = true` and three of four repeat
`powerManagement = "power-profiles-daemon"` — both are already the option defaults.

### 🔵 R9 — ✅ FIXED (`''${XDG_RUNTIME_DIR}` — ssh expands env vars in IdentityAgent) — Hardcoded UID in ssh config
`home/max/cli.nix` sets `IdentityAgent = "/run/user/1000/gnupg/S.gpg-agent.ssh"`. Use
`${config.home.homeDirectory}`-independent `gpgconf --list-dirs agent-ssh-socket` via an env
var, or at least derive from `osConfig.users` — UID 1000 is an assumption.

### 🔵 R10 — ✅ FIXED (kernel/it87 risk documented rather than switching to LTS; `QS_DIR` item was stale — caching.sh uses it now) — Misc small ones
- `modules/home/theme.nix` duplicates `MOZ_ENABLE_WAYLAND` (already set system-wide in `productivity.nix`).
- `xdg.mimeApps`: `video/mkv` is not a registered MIME type — Matroska is `video/x-matroska`.
- kitty `listen_on = "unix:/tmp/kitty"`: all instances share one socket path and clash; use
  `unix:${XDG_RUNTIME_DIR}/kitty` or kitty's `{kitty_pid}` placeholder.
- `boot.kernelPackages = linuxPackages_latest` (base.nix) + out-of-tree `it87` module
  (home-desktop) is a fragile pair — `latest` bumps can break the module and with it
  fancontrol. Consider the default LTS kernel on home-desktop, or accept that risk knowingly.
- `caching.sh` computes `QS_DIR` but never uses it.

---

## 6. Suggestions / improvements

1. **CI** — a GitHub Actions workflow running `nix flake check --no-build`, `statix check`,
   `deadnix -f`, and `shellcheck` would have caught B4/R1 and future drift. The devShell
   already contains all the tools; CI is just running them.
2. **Secrets** (echoing TODO.md, now more urgent per S1) — agenix or sops-nix for the password
   hash and future API keys; rotate the current password afterwards.
3. **Commit the pending work** — the working tree has an unstaged fancontrol fix
   (hwmon6/coretemp correction in `hosts/home-desktop/default.nix`), a `Theme.qml` import fix,
   and a `flake.lock` bump. The fancontrol change in particular is a hardware-correctness fix
   that exists only on this machine until committed.
4. **Pre-commit hook** — wire `nixfmt`/`statix`/`shellcheck` via a simple `.git/hooks` or
   `pre-commit` config in the devShell so 1-letter commits at least ship linted code.
5. **`nixos-hardware` for work-laptop** — already on TODO; the input is wired in `flake.nix`
   and passed as a specialArg but no host consumes it yet.
6. **Backups** — also on TODO; restic with a systemd timer is ~20 lines of module and would
   cover the syncthing-only gap.
7. **Consider `programs.nh.clean`** — you already use `nh`; its built-in clean
   (`programs.nh.clean.enable`) can replace the separate `nix.gc` timer and respects nh
   profiles.

---

## What's in good shape

Worth saying explicitly: the flake evaluates clean for all hosts; module layering
(option-flag base + import-composition optional files) is consistent and well documented;
host-specific hacks (SDDM/KWin monitor pinning, VM cursor workarounds, stylix release-check
suppression, btrfs initrd retry) all carry comments explaining *why*; shellcheck is clean;
deadnix finds nothing; and the live-symlink pattern for Quickshell/Hyprland scripts is a nice
balance of declarative + iterable. The issues above are mostly drift and leftovers, not
structural problems.
