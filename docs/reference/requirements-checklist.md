# Future Additions Backlog

Items listed here are **not** currently managed by any NixOS module.
See `CLAUDE.md` "Adding things" for where to put each type of package or config.

## System

- `chrony` — alternative to `services.timesyncd` for time synchronisation
- `nerd-fonts.symbols-only` — extra Nerd Fonts symbol set

## Development

- `python312Packages.poetry` — Python dependency/virtualenv management
- `devenv` — reproducible per-project dev environments via Nix

## Productivity & Desktop

- `anki` — spaced repetition flashcards

## Backup & Sync

- `restic` / `borgbackup` — file-level backup tools (complement to BTRFS snapshots)

## Security

- `lynis` — system security audit tool

## Gaming / Streaming

- `envycontrol` — GPU switching on NVIDIA hybrid laptops (alternative to `nvidia-prime`)
- `latencyflex` — latency-flex VKLayer (check nixpkgs availability before adding)

## Post-Install Tasks (manual)

- Configure backups (restic, borg) and verify restore workflow
- Run security audit (`lynis audit`)
- Set up Git GPG signing key: add key ID to `flake.nix` under `sharedHmArgs.git.signingkey`; configure `programs.git.signing` in `home/max/git.nix`
- Configure Syncthing peers and shared folders via the web UI at `localhost:8384`
- Verify `hardware-configuration.nix` on each host after first `nixos-generate-config`
