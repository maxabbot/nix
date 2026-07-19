# Repository Audit — 2026-07-07

Scope: full repo on branch `quickshell-settings-expansion` (24 commits ahead of main —
the Quickshell settings expansion + Waybar-first refactor).
Previous audit (2026-06-10) is in git history; its findings were all remediated except
the two carried forward below (S1, B-xorg).

> **2026-07-18 update:** the history has since been squashed to a single init commit —
> the branch and the 2026-06-10 audit referenced above no longer exist in git history.
> Since this audit: `nix.gc` → `programs.nh.clean` (obsoleting the §3 note), Limine
> replaced systemd-boot on the GUI hosts (lanzaboote input/file removed), and a
> follow-up audit fixed accumulated doc drift plus two session bugs (missing polkit
> agent, duplicate gammastep). S1 (secrets) and B-xorg remain open.

Tooling results: `nix flake check --no-build` **passes** for all four hosts.
`deadnix` clean. `shellcheck` clean on all scripts. `statix` reported four
repeated-key warnings (fixed in this pass). `nix fmt` had drifted on two files
(fixed).

Severity key: 🔴 fix soon · 🟡 worth fixing · 🔵 suggestion / cleanup

> **Remediation status (same day):** everything marked ✅ below was fixed in this
> pass. Still open: S1 (secrets — needs an agenix/sops-nix decision + password
> rotation), the xorg deprecation warnings (from a flake input, not our modules),
> and the section-4 suggestions.

---

## 1. Carried forward (still open)

### 🔴 S1 — Password hash committed to the repo (same hash on all four hosts)
Every host sets the identical yescrypt hash in `custom.base.hashedPassword`. Known,
tracked in TODO.md — move to agenix/sops-nix (`hashedPasswordFile`) and rotate the
password once secrets land, since the current hash is in git history.

### 🟡 B-xorg — xorg deprecation warnings on home-desktop
`nix flake check` still emits ~9 *"xorg.libX11 has been renamed to libx11"* warnings
for home-desktop only. They come from a pinned flake input (most likely
`apollo-flake`, the only home-desktop-only input with a package build), not from this
repo's modules. Will become hard errors on a future nixpkgs; worth re-pinning or
raising upstream when apollo-flake updates.

---

## 2. New findings — fixed in this pass

### 🟡 F1 — ✅ FIXED — GUI apps installed on the headless `minimal` host
`home/max/packages.nix` had no compositor gate, so `minimal` received spotify,
cheese, qbittorrent, stremio and — worse — **built Wine-GE** on every host, because
the Lutris runner (`xdg.dataFile."lutris/runners/wine/…"`) was unconditional while
Lutris only ships with `gaming.nix`. Now: GUI packages gated on
`compositor != "none"`, the Wine-GE runner gated on `osConfig.programs.steam.enable`
(the gaming-host signal).

### 🟡 F2 — ✅ FIXED (removed) — Dead workspace fast path in `qs_manager.sh`
Nothing called `qs_manager.sh <number>` (all workspace switching goes through
`hl.dsp.focus` binds and the patched Waybar), and the path used classic
`hyprctl dispatch workspace N` syntax, which this Hyprland's Lua config parser
silently rejects — dead *and* broken.

### 🟡 F3 — ✅ FIXED (deleted) — Orphaned files
- `config/hypr-scripts/clipboard-fuzzel.sh` — superseded by `ClipboardPanel.qml`
  (`Super+Shift+V` routes through `qs_manager.sh toggle clipboard`); no callers.
- `config/wlogout/{layout,style.css}` — wlogout was replaced by `PowerMenu.qml`;
  nothing installed the package or deployed these files.
- `waybar-refactor-plan.md` — completed plan for the already-shipped refactor.

### 🟡 F4 — ✅ FIXED (rewritten) — QUICKSHELL.md / WAYBAR.md described the pre-refactor world
Both docs still documented the deleted Quickshell bottom bar (`Bar.qml`,
`BarButton.qml`, `Workspaces.qml`, `MediaPlayer.qml`), swaync/wlogout, the old
`custom/sysinfo` Waybar module set, and bottom-anchored panels. Rewritten to match
the current two-bar Waybar + tabbed-Settings architecture.

### 🟡 F5 — ✅ FIXED — statix W20 (repeated attribute keys) in four files
`modules/home/wm/hyprland.nix` (`services`), `hosts/work-laptop/default.nix`
(`boot`), `hosts/common/optional/productivity.nix` (`programs`, `systemd`),
`home/max/terminal-toys.nix` (`xdg`). All merged into single blocks. These were
introduced after the June audit; the CI `lint` job doesn't gate this branch until it
opens a PR.

### 🔵 F6 — ✅ FIXED — Doc drift (smaller)
- CLAUDE.md: optional-modules table was missing `stylix.nix` and `fan2go.nix`;
  `home/max` file list was missing `terminal-toys.nix`; the "Live-editable script"
  row was wrong (scripts are store symlinks — edits need `git add` + `nixup` +
  a quickshell restart for QML); theme section now mentions Stylix ownership.
- TODO.md: claimed work-laptop's `hardware-configuration.nix` was a placeholder —
  it's real now (ThinkBook, portable USB SSD); only `minimal` remains a placeholder.
- PACKAGES.md: still listed **Swaync** and **wlogout** (both replaced by Quickshell),
  and credited `Ctrl+R` to fzf (atuin owns it now; atuin wasn't listed at all).
- docs/SHORTCUTS.md: tmux split binds documented as `%`/`"` but shell.nix rebinds
  them to `|`/`-`; sessionizer is `Prefix+f`.
- README.md: module one-liners updated (atuin, VSCode, kanshi, Stylix split).

### 🔵 F7 — ✅ FIXED — mpv/zathura installed twice
`productivity.nix` `systemPackages` duplicated `mpv` and `zathura`, which Home
Manager already installs (with config) via `programs.mpv` / `programs.zathura`.
System copies removed. (base.nix's CLI overlaps — git/tmux/btop/etc. — are left
alone deliberately: they keep root and other users functional.)

### 🔵 F8 — ✅ FIXED — `nix fmt` drift in two files
`home/max/desktop.nix` (one-line attrsets), `modules/home/wm/waybar.nix`. The CI
nixfmt job would have failed the eventual PR.

---

## 3. Observations (no action taken — deliberate or low value)

- **`base.nix` battery udev rule** uses `chmod 0666` on
  `charge_control_end_threshold` — world-writable sysfs. Any local process can set
  the charge limit. Low impact (it's a charge threshold, bounded by the kernel
  driver), but `0664` + `GROUP="users"` would be tighter if it ever bothers you.
- **Commit messages**: 5 of 24 commits on this branch are single-letter (`v`).
  Same note as last audit — the history is the one place intent can't be
  reconstructed from the working tree.
- **`custom.base.fancontrol`** options remain in base.nix although home-desktop now
  uses fan2go. Kept: the option is generic, documented, and another host could use it.
- **`nix.gc` vs `programs.nh.clean`** — still on the old-style GC timer; works fine,
  nh's clean is marginally nicer with nh profiles. Optional.

## 4. Suggestions (unchanged from TODO.md)

1. **Secrets** — agenix or sops-nix for the password hash; rotate afterwards (S1).
2. **Backups** — restic/borgbackup + systemd timer; syncthing doesn't cover disk failure.
3. **nixos-hardware for work-laptop** — input is wired and passed as a specialArg;
   no host consumes it yet.
4. **GPG commit signing** — `signingkey` hmArg + `programs.gpg` in HM.

---

## What's in good shape

The flake evaluates clean for all hosts; CI (flake check, nixfmt, shellcheck,
statix/deadnix) is in place and the devShell carries the same tools; module layering
is consistent and every host-specific hack carries a *why* comment; all QML panels
are referenced and the Settings tab wiring (Settings.qml ⇄ Shell.qml ⇄ qs_manager
prep) is consistent; scripts are shellcheck-clean; flake inputs are fresh (all
key inputs < 1 week old). The issues this time were almost entirely doc drift and
leftovers from the bar refactor — the Nix architecture itself needed nothing
structural.
