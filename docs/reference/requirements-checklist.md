# Future Additions Backlog

Items listed here are **not** currently installed by any Ansible role.
Add them to the appropriate `system/roles/<role>/vars/main.yml` when needed.

## System

- `chrony` — alternative to systemd-timesyncd for time synchronisation
- `ttf-nerd-fonts-symbols` — extra Nerd Fonts symbol set

## Development

- `poetry` — Python dependency/virtualenv management
- `devenv` / `nix` — reproducible dev environments

## Productivity & Desktop

- `anki` — spaced repetition flashcards

## Backup & Sync

- `restic` / `borg` — file-level backup tools (complement to Timeshift snapshots)

## Security

- `lynis` — system security audit tool

## Gaming / Streaming

- `envycontrol` — GPU switching on NVIDIA hybrid laptops (alternative to `nvidia-prime`)

## Post-Install Tasks (manual)

- Configure backups (restic, borg, timeshift) and verify restore workflow
- Schedule reflector timer and create pacman hook automation
- Run security audit (`lynis audit`)
- Set up Git signing key and add public key to GitHub/GitLab
- Configure Syncthing peers and shared folders
