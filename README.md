# linux-setup-scripts

Infrastructure-as-Code automation for rebuilding Arch Linux workstations — from bare metal to a fully configured desktop in three layers.

## Architecture

```text
+---------------------------------------------------+
|  Layer 1 — Bootstrap (archinstall)                |
|  Partition disks, install base system, reboot     |
+---------------------------------------------------+
|  Layer 2 — System Configuration (Ansible)         |
|  Packages, services, drivers, system tweaks       |
+---------------------------------------------------+
|  Layer 3 — User Environment (Chezmoi)             |
|  Dotfiles, shell config, editor, WM themes        |
+---------------------------------------------------+
```

| Layer | Tool | Directory | Purpose |
|-------|------|-----------|---------|
| Bootstrap | archinstall | `bootstrap/` | Automated Arch installation from ISO |
| System | Ansible | `system/` | Package management, services, drivers |
| User | Chezmoi | `user/` | Dotfiles and user-space configuration |

## Repository layout

```text
setup.sh              # Single entry point — runs everything
bootstrap/            # archinstall JSON configs (Layer 1)
system/               # Ansible playbooks, roles, and inventory (Layer 2)
  ├─ playbooks/      #   site.yml + per-role playbooks
  ├─ roles/          #   aur, base, development, productivity, nvidia, gaming
  ├─ inventory/      #   hosts.yml (localhost)
  └─ group_vars/     #   Profile variables (home_desktop, work_laptop)
user/                 # Chezmoi source directory (Layer 3)
  ├─ dot_zshrc       #   Shell configs
  ├─ dot_config/     #   nvim, hyprland, sway, waybar
  └─ run_onchange_*  #   Auto-install scripts for shell deps
docs/                 # Guides and reference material
```

## Quick start

### Full setup (post-install)

After a fresh Arch install (via archinstall or manually):

```bash
git clone https://github.com/maxabbot/linux-setup-scripts.git
cd linux-setup-scripts
chmod +x setup.sh
./setup.sh
```

The script will:
1. Install prerequisites (git, ansible, chezmoi)
2. Install Ansible Galaxy collections
3. Let you pick a profile (Home Desktop, Work Laptop, Minimal, Custom)
4. Run the system playbook with `--ask-become-pass`
5. Optionally apply Chezmoi dotfiles

### From the Arch ISO (Layer 1)

```bash
archinstall --config bootstrap/archinstall/user-configuration.json \
            --creds bootstrap/archinstall/user-credentials.json
```

See [bootstrap/README.md](bootstrap/README.md) for customisation details.

### Running Ansible directly (Layer 2)

```bash
cd system

# Full home desktop
ansible-playbook playbooks/site.yml -i inventory/hosts.yml -l home_desktop --ask-become-pass

# Work laptop
ansible-playbook playbooks/site.yml -i inventory/hosts.yml -l work_laptop --ask-become-pass

# Single role
ansible-playbook playbooks/development.yml -i inventory/hosts.yml --ask-become-pass

# Specific tags
ansible-playbook playbooks/site.yml -i inventory/hosts.yml --tags "base,development" --ask-become-pass
```

### Applying dotfiles directly (Layer 3)

```bash
chezmoi init --source ./user --apply
```

See [user/README.md](user/README.md) for template variables and customisation.

## Profiles

| Profile | Roles | Use case |
|---------|-------|----------|
| `home_desktop` | base, development, productivity, nvidia, gaming | RTX 40-series desktop with full stack |
| `work_laptop` | base, development, productivity | Dev-focused laptop (no GPU/gaming) |
| Minimal | base | Bare essentials only |
| Custom | pick and choose | Interactive role selection |

## Feature toggles

Override defaults in `system/inventory/group_vars/all.yml` or per-profile in `system/inventory/group_vars/home_desktop.yml` / `work_laptop.yml`:

| Variable | Default | home_desktop | work_laptop | Effect |
|----------|---------|:---:|:---:|--------|
| `enable_docker` | `false` | | ✓ | Enable Docker daemon and add user to docker group |
| `enable_libvirt` | `false` | | | Enable libvirtd/KVM virtualisation |
| `enable_database_servers` | `false` | ✓ | ✓ | Install PostgreSQL, MariaDB, Redis, SQLite |
| `enable_gui_db_clients` | `false` | ✓ | ✓ | Install DBeaver, pgAdmin, litecli |
| `enable_data_platforms` | `false` | | | Install Airflow, Spark, DuckDB |
| `enable_cuda_stack` | `false` | ✓ | | Install CUDA/cuDNN alongside NVIDIA drivers |
| `enable_creative_suite` | `false` | ✓ | | Install GIMP, Krita, Inkscape |
| `enable_streaming_tools` | `false` | | | Install streaming/remote desktop tools |
| `enable_secondary_browsers` | `false` | | | Install Brave, Zen alongside Firefox |
| `enable_sync_clients` | `false` | | | Install Syncthing, Nextcloud, Dropbox |
| `enable_gufw` | `false` | | | Install the GUFW firewall UI |
| `install_apollo` | `false` | | | Install Apollo streaming client |
| `power_management` | `power-profiles-daemon` | | `tlp` | Choose `tlp` or `power-profiles-daemon` |
| `reflector_countries` | `'New Zealand,Australia'` | | | Countries for pacman mirror selection |

## Ansible roles

| Role | Tag | Description |
|------|-----|-------------|
| `aur` | `aur` | Bootstrap yay/paru AUR helper (always runs first) |
| `base` | `base` | Core packages, networking, filesystems, fonts, services |
| `development` | `development` | Languages, editors, containers, cloud CLIs, databases |
| `productivity` | `productivity` | Desktop apps, browsers, office, media, communication |
| `nvidia` | `nvidia` | Proprietary drivers, CUDA, Coolbits, mkinitcpio hooks |
| `gaming` | `gaming` | Steam, Wine, Proton, controllers, performance tools |

## User environment

Dotfiles are managed with [Chezmoi](https://www.chezmoi.io/) and include:

- **Shell** — Zsh (Antidote + Powerlevel10k) with Bash fallback
- **Editor** — Neovim (lazy.nvim, LSP, Mason, Treesitter, Telescope)
- **WMs** — Hyprland + Sway (with templated monitor configs)
- **Theme** — Catppuccin Mocha everywhere
- **Bar** — Waybar with unified styling

## Documentation

| Document | Description |
|----------|-------------|
| [bootstrap/README.md](bootstrap/README.md) | Layer 1 — archinstall configuration |
| [system/README.md](system/README.md) | Layer 2 — Ansible roles and playbooks |
| [user/README.md](user/README.md) | Layer 3 — Chezmoi dotfiles |
| [docs/post-installation.md](docs/post-installation.md) | Post-install checklist |
| [docs/SHORTCUTS.md](docs/SHORTCUTS.md) | Keyboard shortcuts and shell aliases reference |

## Contributing

1. Fork and create a feature branch
2. Keep changes modular — extend roles or add new ones
3. Test with `ansible-playbook --check` (dry run)
4. Lint shell scripts with `shellcheck`
5. Open a PR against `main`

## License

[MIT](LICENSE)
