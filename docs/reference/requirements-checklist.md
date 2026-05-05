# Future Additions Backlog

Items listed here are **not** currently managed by any NixOS module.
Add them to the appropriate `modules/nixos/<module>.nix` or `modules/home/<module>.nix` when needed.

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
- Set up Git GPG signing key: add key ID to `home/max/default.nix` under `programs.git.signing`
- Configure Syncthing peers and shared folders via `services.syncthing`
- Verify `hardware-configuration.nix` on each host after first `nixos-generate-config`
