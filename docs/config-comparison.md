# NixOS Config Comparison

Comparing this repo against [Misterio77/nix-config](https://github.com/Misterio77/nix-config) and [fufexan/dotfiles](https://github.com/fufexan/dotfiles).

---

## Architecture / Module Pattern

**This repo** uses import composition for everything except base system config. `hosts/common/optional/` holds 15+ standalone config files; hosts list what they need in `imports = [...]`. `modules/nixos/base.nix` is the only remaining option-flag module (timezone, username, power management). This matches the Misterio77 pattern.

**Misterio77** uses import-based composition — `hosts/common/global/` (always loaded) + `hosts/common/optional/` (imported per-host). No option namespace at all; each feature is a standalone file that's either in the import list or isn't.

**fufexan** uses `flake-parts` as the flake framework instead of a hand-rolled `mkHost`, with a `system/` top-level for NixOS config split by category (`system/core/`, `system/hardware/`, `system/network/`, etc.).

---

## Home Manager Structure

**This repo**: `home/max/` split into `default.nix` (entry), `git.nix`, `cli.nix`, `desktop.nix`, `packages.nix`. Shared `git` args extracted into `sharedHmArgs` in `flake.nix` so per-host hmArgs only contain what differs.

**Misterio77**: `home/gabriel/features/cli/`, `features/desktop/hyprland/`, `features/games/`, etc. Per-host home files (`alcyone.nix`, `atlas.nix`) import only the features that host needs.

**fufexan**: `home/terminal/`, `home/programs/`, `home/services/`, `home/editors/`, `home/profiles/` for coarse machine roles.

This repo's split is shallower than the references — features aren't composable per-host yet — but it's no longer a single monolithic file.

---

## Secrets Management

**This repo**: None. `signingkey = ""`, `sshKeys = []`, initial password hardcoded.

**Misterio77**: `sops-nix` — encrypted `secrets.yaml` per host, committed to git, decrypted at activation via age/GPG.

**fufexan**: `agenix` — `secrets/*.age` files, same model.

This is the most important gap. Real SSH keys, API tokens, and hashed passwords require one of these.

---

## Feature Matrix

| Feature | This repo | Misterio77 | fufexan |
|---|---|---|---|
| Secure boot | Ready (lanzaboote.nix, not yet enrolled) | lanzaboote | lanzaboote |
| Secrets | No | sops-nix | agenix |
| Impermanence | No | Yes (ephemeral btrfs root) | No |
| Binary cache | No | Self-hosted (cache.m7.rs) | Cachix |
| Hyprland config | Nix DSL | Nix DSL | Lua files |
| Bar | waybar | waybar | Quickshell (QML) |
| CI | GitHub Actions | Hydra (self-hosted) | GitHub Actions |
| Git signing | Empty key | GPG | GPG |
| Flake framework | Hand-rolled mkHost | Hand-rolled | flake-parts |
| HM structure | Feature files | Feature directories | Category directories |
| Module pattern | Import composition (+ base options) | Import composition | Import composition |

---

## What's Worth Adopting

### Still to do

**Low effort, high value:**
- **Secrets management** (sops-nix or agenix) — unblocks real deployment; nothing else matters until this is in place
- **`nh`** — nicer rebuild UX: `nh os switch` diffs what will change before applying, auto-detects flake path, cleans old generations; replaces the `nixup` alias
- **`nix-index` + `comma`** — run any nixpkgs package without installing it (`, ffprobe`); pair with `nix-index-database` to skip building the index locally
- **`statix` + `deadnix` in CI** — Nix linters; catches unused vars, deprecated patterns, dead code; two lines in `.github/workflows/ci.yml`

**Medium value:**
- **`nixos-hardware` modules** — flake imports it but no host uses it; `home-desktop` has relevant modules for Intel i7-13700K and RTX 40-series; gives better firmware/driver defaults for free
- **GPG commit signing** — both references sign commits; `signingkey = ""` is a stub
- **Specialisations for `work-laptop`** — fufexan pattern; adds a `powersave` boot entry alongside default; one file, no ongoing cost
- **Dev shell for the config** — `nix develop` gives nixfmt, statix, deadnix without polluting the system; Misterio77 has `shell.nix`, fufexan has `devShells.default`

**Only matters with multiple real hosts:**
- **Tailscale** — both repos use it to mesh hosts; irrelevant until `minimal` is deployed somewhere
- **Binary cache / Cachix** — worth it once custom derivations take time to build; pointless while `pkgs/` is empty

**Advanced / optional:**
- **Impermanence** — ephemeral root forces explicit declaration of all persistent state; very clean but requires upfront planning
- **flake-parts** — only worth migrating to if the flake gets significantly more complex
