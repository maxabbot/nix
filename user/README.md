# User Layer — Chezmoi Dotfiles

This layer manages **user-level configuration** — shell configs, editor settings, and window manager themes — using [chezmoi](https://www.chezmoi.io/).

## Quick Start

### Option 1: Use chezmoi directly from this directory

```bash
cd user
chezmoi init --source .
chezmoi apply --dry-run    # preview changes
chezmoi apply              # apply dotfiles
```

### Option 2: Via the main setup.sh

The top-level `setup.sh` offers to apply dotfiles automatically after system configuration.

## Directory Structure

```
user/
├── .chezmoi.toml.tmpl              # Machine-specific template variables
├── run_onchange_install-shell-deps.sh  # Sets default shell to zsh
├── dot_zshrc                       # ~/.zshrc
├── dot_bashrc                      # ~/.bashrc
├── dot_p10k.zsh                    # ~/.p10k.zsh (Powerlevel10k config)
└── dot_config/
    ├── nvim/                       # ~/.config/nvim (IDE-like setup)
    │   ├── init.lua
    │   └── lua/
    │       ├── config/
    │       │   ├── options.lua
    │       │   └── keymaps.lua
    │       └── plugins/
    │           ├── lsp.lua
    │           ├── cmp.lua
    │           ├── treesitter.lua
    │           └── ui.lua
    ├── hyprland/                   # ~/.config/hyprland
    │   ├── hyprland.conf.tmpl      # Templated for monitor config
    │   ├── waybar-config.json
    │   └── waybar-style.css
    ├── sway/                       # ~/.config/sway
    │   ├── config.tmpl             # Templated for monitor config
    │   ├── waybar-config.json
    │   └── waybar-style.css
    └── waybar/
        └── style.css               # Shared waybar theme
```

## Template Variables

Set in `.chezmoi.toml.tmpl` during `chezmoi init`:

| Variable | Description | Example |
|----------|-------------|---------|
| `machine.type` | `desktop` or `laptop` | `desktop` |
| `machine.hostname` | System hostname | `archlinux` |
| `machine.timezone` | Timezone | `America/New_York` |
| `monitors.primary` | Primary monitor config | `DP-1,2560x1440@165,0x0,1` |
| `monitors.secondary` | Secondary monitor | `HDMI-A-1,1920x1080@60,2560x0,1` |
| `wm.compositor` | Window manager | `hyprland` or `sway` |

## Theme

All configs use the **Catppuccin Mocha** color scheme:

| Role | Color |
|------|-------|
| Base | `#1e1e2e` |
| Text | `#cdd6f4` |
| Blue | `#89b4fa` |
| Mauve | `#cba6f7` |
| Green | `#a6e3a1` |
| Red | `#f38ba8` |
| Yellow | `#f9e2af` |

## Shell Features

- **Zsh**: Antidote + Powerlevel10k + autosuggestions/syntax-highlighting
- **Bash**: Git-aware prompt, colored man pages, same aliases/functions
- Shared aliases for: pacman, git, docker, python, rust, node/npm/yarn
- Custom functions: `mkcd`, `extract`, `sysup`, `mkvenv`, `serve`, `dclean`
- Integration: zoxide, direnv, fzf

## Neovim Stack

- Plugin manager: lazy.nvim
- LSP: pyright, rust-analyzer, tsserver, bashls, lua_ls (via Mason)
- Completion: nvim-cmp + LuaSnip
- Treesitter: 18 language parsers
- UI: catppuccin, telescope, nvim-tree, lualine, bufferline, which-key, gitsigns

## Local Overrides

Both shell configs source a local override file if present:
- `~/.zshrc.local`
- `~/.bashrc.local`

Use these for machine-specific settings that shouldn't be tracked in git.
