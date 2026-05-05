# Bootstrap Layer

This layer handles the initial Arch Linux installation using **archinstall**.

## Files

| File | Purpose |
|------|---------|
| `archinstall/user-configuration.json` | Main archinstall config (disk layout, packages, locale, bootloader) |
| `archinstall/user-credentials.json.example` | Template for user credentials — **never commit real passwords** |

## Usage

### From the Arch ISO

1. Boot into the Arch Linux live environment.
2. Connect to the internet (`iwctl` for Wi-Fi).
3. Copy the config files onto the live environment (USB, `curl`, etc.):

```bash
# Option A: clone the repo
pacman -Sy git
git clone https://github.com/maxabbot/linux-setup-scripts.git
cd linux-setup-scripts/bootstrap/archinstall

# Option B: fetch just the configs
curl -LO https://raw.githubusercontent.com/maxabbot/linux-setup-scripts/main/bootstrap/archinstall/user-configuration.json
```

4. Create your credentials file:

```bash
cp user-credentials.json.example user-credentials.json
# Edit with your username and password
nano user-credentials.json
```

5. Run archinstall:

```bash
archinstall --config user-configuration.json --creds user-credentials.json
```

### Customisation

**Disk layout**: The config uses auto-detection for disks. When you run archinstall, you will be prompted interactively to:
1. Select your target disk (e.g. `/dev/sda` or `/dev/nvme0n1`)
2. Choose a partition scheme (default is Btrfs with subvolumes)
3. Review and confirm the layout

Before running archinstall, confirm your available disks:
```bash
lsblk
```

**Graphics driver**: Change `profile_config.gfx_driver` to match your GPU:
- `"Nvidia (proprietary)"` — NVIDIA
- `"AMD / ATI (open-source)"` — AMD
- `"Intel (open-source)"` — Intel
- `"All open-source"` — safe catch-all

**Desktop**: Change `profile_config.profile.details` to `["Sway"]`, `["Hyprland"]`, or `["Minimal"]`.

**Locale**: Update `locale_config.sys_lang` for your region (e.g. `"en_US"`, `"en_GB"`, `"en_NZ"`).

**Mirror region**: Update `mirror_config.mirror_regions` for your country.

**Timezone**: Update `timezone` to your local timezone (e.g., `Europe/London`, `America/Chicago`, `Pacific/Auckland`).

## After archinstall

Once archinstall completes and you reboot into the new system, run the **system layer**:

```bash
cd ~/linux-setup-scripts
./setup.sh
```

## Security Notes

- **Never commit** `user-credentials.json` with real passwords.
- The `.gitignore` at the repo root excludes `user-credentials.json`.
- For automated deployments, consider using Ansible Vault or `pass` for secrets.
