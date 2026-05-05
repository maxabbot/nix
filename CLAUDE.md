# CLAUDE.md

## Project Overview

Arch Linux workstation provisioning framework with three independent, idempotent layers:

1. **Bootstrap** (`bootstrap/`) — archinstall JSON configs for bare-metal Arch installation
2. **System** (`system/`) — Ansible playbooks for packages, services, and system configuration
3. **User** (`user/`) — Chezmoi-managed dotfiles (shell, editor, WM, theme)

Entry point: `setup.sh` orchestrates all three layers sequentially.

## Repository Structure

```
setup.sh                    # Main entry point (Layer 1→2→3 orchestration)
bootstrap/archinstall/      # archinstall JSON configs
system/
  ansible.cfg               # Ansible config (local connection, become=sudo)
  requirements.yml          # Galaxy collections (community.general, ansible.posix, kewlfft.aur)
  inventory/
    hosts.yml               # Localhost with unique host aliases per profile
    group_vars/
      all.yml               # Feature toggles and defaults
      home_desktop.yml      # Desktop profile (base+dev+prod+nvidia+gaming)
      work_laptop.yml       # Laptop profile (base+dev+prod)
      minimal.yml           # Minimal profile (base only)
  playbooks/
    site.yml                # Main playbook (runs all roles conditionally)
    base.yml, development.yml, productivity.yml, nvidia.yml, gaming.yml  # Single-role wrappers
  roles/
    aur/                    # Bootstraps AUR helper (yay/paru)
    base/                   # Core packages, networking, filesystems, services, fonts
    development/            # Languages, editors, containers, cloud CLIs, databases
    productivity/           # Desktop apps, browsers, office, media, creative suite
    nvidia/                 # Drivers, CUDA, mkinitcpio hooks, kernel params
    gaming/                 # Steam, Wine, Proton, controllers, game launchers
user/                       # Chezmoi source directory (dot_* naming convention)
docs/                       # Post-installation guide, reference checklists
```

## Key Conventions

### Ansible

- **Profiles** use unique host aliases in inventory (`home_desktop_host`, `work_laptop_host`, `minimal_host`) to avoid group_vars precedence conflicts.
- **Feature toggles** in `group_vars/all.yml` gate optional packages (docker, libvirt, CUDA, creative suite, etc.). Profile-specific overrides live in their own group_vars file.
- **Roles** follow standard Ansible layout: `tasks/main.yml`, `vars/main.yml`, `handlers/main.yml`. Package lists live in `vars/main.yml`.
- **AUR packages** use the `kewlfft.aur` collection. The `aur` role always runs first (tagged `always`) to bootstrap the helper.
- All tasks must be **idempotent** — safe to run repeatedly.
- `site.yml` runs a `pacman -Syu` in pre_tasks, then applies roles gated by the `profile_roles` variable.

### Running Ansible

```bash
cd system
ansible-playbook playbooks/site.yml -i inventory/hosts.yml -l home_desktop --ask-become-pass
ansible-playbook playbooks/site.yml -i inventory/hosts.yml -l work_laptop --ask-become-pass
ansible-playbook playbooks/site.yml -i inventory/hosts.yml -l minimal --ask-become-pass
```

### Chezmoi (user/)

- Files use Chezmoi naming: `dot_zshrc`, `dot_config/`, etc.
- Templates (`.tmpl` suffix) are parameterized via `.chezmoi.toml.tmpl` (machine type, hostname, monitors, compositor).
- `run_onchange_*.sh` scripts auto-install shell dependencies on first apply.
- Theme: **Catppuccin Mocha** applied across all configs.

### Shell Scripts

- Linted with **shellcheck** (CI enforced). Config: `.shellcheckrc` enables `external-sources=true`.
- Use `bash` with proper quoting and error handling.

## CI/CD

GitHub Actions (`.github/workflows/ci.yml`): runs **shellcheck** on all `.sh` files and **bats** for any tests in `tests/`.

## Adding Packages

1. Add the package name to the appropriate list in `system/roles/<role>/vars/main.yml`.
2. If AUR-only, use the `aur_packages` list (installed via `kewlfft.aur.aur` module).
3. If the package should be optional, gate it behind a feature toggle in `group_vars/all.yml`.
4. Update `ANSIBLE_PACKAGES.md` if it exists as generated docs.

## Adding a New Role

1. Create `system/roles/<name>/` with `tasks/main.yml`, `vars/main.yml`, and optionally `handlers/main.yml`.
2. Add the role to `system/playbooks/site.yml` with a `when: "'<name>' in (profile_roles | default([]))"` condition.
3. Optionally create a single-role wrapper playbook in `system/playbooks/<name>.yml`.
4. Add the role to relevant profile group_vars files.

## Security

- Never commit credentials — `user-credentials.json` and `github_pat` are in `.gitignore`.
- AUR helper sudoers is scoped to pacman only (not full NOPASSWD).
- No hardcoded secrets anywhere in the repo.
