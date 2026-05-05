# System Layer — Ansible

This layer handles **system-level configuration** — packages, services, kernel parameters, and driver setup — using Ansible playbooks and roles.

## Quick Start

```bash
cd system

# 1. Install Ansible Galaxy dependencies
ansible-galaxy install -r requirements.yml

# 2. Run the full playbook for your profile
ansible-playbook playbooks/site.yml -l work_laptop --ask-become-pass
ansible-playbook playbooks/site.yml -l home_desktop --ask-become-pass

# Or base-only (minimal)
ansible-playbook playbooks/site.yml -l minimal --ask-become-pass
```

## Directory Structure

```
system/
├── ansible.cfg                 # Ansible configuration
├── requirements.yml            # Galaxy dependencies
├── inventory/
│   ├── hosts.yml               # Inventory (profile host aliases)
│   └── group_vars/
│       ├── all.yml             # Default variables & feature toggles
│       ├── home_desktop.yml    # Home desktop profile overrides
│       ├── work_laptop.yml     # Work laptop profile overrides
│       └── minimal.yml         # Minimal (base-only) profile
├── playbooks/
│   ├── site.yml                # Full system playbook
│   ├── base.yml                # Base packages only
│   ├── development.yml         # Dev tools only
│   ├── productivity.yml        # Productivity apps only
│   ├── nvidia.yml              # NVIDIA drivers only
│   └── gaming.yml              # Gaming packages only
└── roles/
    ├── aur/                    # AUR helper installation
    ├── base/                   # Core system, networking, CLI tools
    ├── development/            # Languages, containers, cloud tools
    ├── productivity/           # Desktop, office, browsers, media
    ├── nvidia/                 # NVIDIA driver stack & CUDA
    └── gaming/                 # Steam, Wine, performance tools
```

## Profiles

Select a profile with the `-l` (limit) flag. Each profile maps to a group in
`inventory/hosts.yml` with its own `group_vars/` overrides:

| Profile (`-l`) | Roles applied | Notes |
|----------------|--------------|-------|
| `home_desktop` | base, dev, prod, nvidia, gaming | RTX 40-series, CUDA enabled |
| `work_laptop` | base, dev, prod | TLP power management, no gaming |
| `minimal` | base | Core packages and services only |

## Feature Toggles

Override in `group_vars/all.yml` or per-profile:

| Variable | Default | Description |
|----------|---------|-------------|
| `power_management` | `power-profiles-daemon` | `power-profiles-daemon` or `tlp` |
| `enable_docker` | `false` | Install Docker + docker-compose |
| `enable_libvirt` | `false` | Install QEMU/KVM + virt-manager |
| `enable_database_servers` | `false` | PostgreSQL, MariaDB, Redis, SQLite |
| `enable_gui_db_clients` | `false` | DBeaver, pgcli, mycli, litecli |
| `enable_data_platforms` | `false` | Airflow, Spark, DuckDB |
| `enable_cuda_stack` | `false` | CUDA, cuDNN (nvidia role) |
| `enable_creative_suite` | `false` | GIMP, Inkscape, Krita |
| `enable_streaming_tools` | `false` | Shotcut, RustDesk, AnyDesk |
| `enable_secondary_browsers` | `false` | Brave, Zen Browser |
| `enable_sync_clients` | `false` | Dropbox, Google Drive, MEGA |
| `install_apollo` | `false` | Apollo game launcher |

## Running Specific Tags

Roles are gated by `profile_roles`, so always specify a limit or pass `profile_roles` explicitly:

```bash
# Only base + development (work_laptop profile already includes both)
ansible-playbook playbooks/site.yml -l work_laptop --tags base,development --ask-become-pass

# Override profile_roles ad-hoc
ansible-playbook playbooks/site.yml -l minimal \
  -e 'profile_roles=["base","development"]' --ask-become-pass

# Skip gaming on home_desktop
ansible-playbook playbooks/site.yml -l home_desktop --skip-tags gaming --ask-become-pass
```

## Idempotency

All tasks are idempotent — running them multiple times produces the same result. Ansible will skip already-installed packages and already-enabled services.
