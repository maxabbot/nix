# What You Get

A "what did I set up" reference. For keybinds see `docs/SHORTCUTS.md`, for structure see `CLAUDE.md`.

---

## Shell

- **Zsh** — autosuggestions, syntax highlighting, history substring search
- **Starship** — Gruvbox Material powerline prompt with git status, language versions, time
- **zoxide** — replaces `cd`; learns your directories (`cd` still works)
- **fzf** — fuzzy finder wired to `Ctrl+T` (files), `Ctrl+R` (history), `Alt+C` (dirs)
- **tmux** — `Ctrl+A` prefix, vim pane navigation, Gruvbox theme, sessionizer on `Ctrl+F`
- **bat** — replaces `cat` and `less`; syntax highlighting, Gruvbox theme
- **eza** — replaces `ls`; icons, git status, tree view via `lt`
- **delta** — replaces git's diff output; side-by-side, line numbers, Gruvbox
- **direnv** — auto-loads `.envrc` / `nix develop` shells on `cd`
- **mise** — runtime version manager (Node, Python, Ruby, etc.) activated in zsh
- `, <pkg>` — run any nixpkgs package without installing (`comma`); e.g. `, ffprobe`
- `nix locate <file>` — find which package owns a file (`nix-index`)
- **dust** — replaces `du`; tree-style disk usage
- **duf** — replaces `df`; coloured, grouped output
- **procs** — replaces `ps`; coloured, human-readable process list
- **sd** — replaces `sed` for find-and-replace; intuitive syntax
- **just** — command/task runner (`justfile`); pairs with devshells
- **watchexec** — run a command whenever files change
- **tldr** — simplified man-page examples (`tealdeer` client)
- **glow** — render markdown in the terminal

Key aliases: `nixup` (rebuild), `gcclean` (garbage collect), `d`/`p` (podman), `g` (git). See `docs/SHORTCUTS.md`.

---

## Desktop (Hyprland hosts)

- **Hyprland** — tiling Wayland compositor; monitor layout generated from Nix per-host
- **Waybar** — status bar; workspaces, clock, system tray
- **Quickshell** — notification overlay and widget layer
- **SDDM** — display manager; KWin Wayland greeter on DP-3 only (home-desktop)
- **fuzzel** — app launcher (`Super+D`), Gruvbox theme
- **Kitty** — terminal; JetBrainsMono Nerd Font 13pt, Gruvbox palette, tab bar
- **awww** — wallpaper daemon
- **hyprlock** — lockscreen; triggered on idle (5 min) and suspend
- **hypridle** — idle daemon; locks at 5 min, suspends at 15 min
- **Gammastep** — night light; manual lat/long per host, 6500K day → 3500K night
- **Swaync** — notification centre (`Super+N`)
- **cliphist** — clipboard history (`Super+Shift+V`)
- **wlogout** — power menu (`Super+Shift+E`)
- **Thunar** — file manager (`Super+E`); archive plugin, thumbnail support via tumbler
- **Yazi** — terminal file manager
- **Syncthing** — file sync daemon; web UI at `localhost:8384`

---

## Applications (always on desktop hosts)

| App | Purpose |
|-----|---------|
| Zen Browser | Primary browser |
| Thunderbird | Email |
| Element | Matrix chat |
| Obsidian | Notes |
| Bitwarden | Passwords |
| LibreOffice | Office suite |
| OnlyOffice | MS Office-compatible editing |
| Zathura | PDF viewer (vim keybinds, Gruvbox) |
| mpv | Video player (vim keybinds, hardware decode) |
| VLC | Media fallback |
| Calibre | Ebook manager |
| Spotify | Music |
| Stremio | Streaming |
| qBittorrent | Torrents |
| Veracrypt | Encrypted volumes |
| rclone | Cloud storage sync |
| nvtop | GPU monitor |
| OpenRGB | RGB lighting control |
| btop | System monitor (Gruvbox, vim keys) |
| fastfetch | System info |

---

## Communications (always on desktop hosts)

| App | Purpose |
|-----|---------|
| Slack | Work chat |
| Discord | Community chat |
| Zoom | Video calls |

---

## Development (all desktop hosts)

- Python 3 + pip, virtualenv, numpy, pandas, scipy, scikit-learn, matplotlib
- Go, Rust (via rustup), JDK, GCC, Clang, CMake, make
- `uv` — fast Python package/project manager
- `bun` — JS runtime + package manager
- `yq` — YAML/JSON/TOML processor
- `shellcheck`, `cloc`, `tig`, `sqlite`, `pgcli`
- `curlie` (httpie-style curl), `bruno` (API client), `httpie`, `mkcert`
- `ffmpeg`, `imagemagick`, `pandoc`
- `quickemu` / `quickgui` — VM management without libvirt
- Podman + Docker-compat aliases (`d ps`, `d images`, etc.)
- kubectl, helm, opentofu, awscli2, azure-cli, google-cloud-sdk, doctl
- `granted` (`assume` — multi-account AWS role switching), `aws-sam-cli` (local Lambda/API GW), `awslogs` (tail CloudWatch), `localstack` (local AWS emulation), `steampipe` (query AWS as SQL)
- `visidata` (TUI table explorer), `miller`/`mlr` (CSV/JSON reshaping), `dasel` (jq across formats), `qsv` (fast CSV ops)
- DBeaver, Beekeeper Studio, mycli, litecli, DuckDB
- `gh` — GitHub CLI
- `nix-tree`, `nix-diff`, `nixpkgs-review`, `nil` — Nix dev tools
- `claude-code` — AI assistant CLI

---

## Creative (home-desktop only)

| App | Purpose |
|-----|---------|
| GIMP | Image editor |
| Inkscape | Vector graphics |
| Krita | Digital painting |

---

## Streaming & Content (home-desktop only)

| App | Purpose |
|-----|---------|
| OBS Studio | Screen/game capture and streaming |
| Shotcut | Video editor |
| LosslessCut | Fast lossless video trimmer |
| gpu-screen-recorder | Low-overhead GPU-accelerated recorder |
| RustDesk | Remote desktop |
| Moonlight | Game streaming client |
| Apollo | Game streaming host (Sunshine fork) |

---

## Gaming (home-desktop only)

- **Steam** — Proton GE pre-installed, Gamescope session available
- **Gamemode** — CPU governor boost on game launch (renice 10)
- **Gamescope** — micro-compositor for resolution scaling / VRR
- **MangoHud** — in-game performance overlay
- **Heroic** — GOG / Epic Games launcher
- **Lutris** — multi-platform game manager
- **itch** — itch.io client
- **ProtonUp-Qt** — Proton GE version manager
- **protontricks** — Winetricks wrapper for Steam games
- **GOverlay** — MangoHud / vkbasalt GUI configurator
- **vkbasalt** — Vulkan post-processing (CAS sharpening, FXAA)
- **xpadneo** — Xbox controller kernel module (Bluetooth)
- Wine (WoW64 staging) + winetricks + DXVK
- `vm.max_map_count` raised for anti-cheat / large games

---

## NVIDIA (home-desktop only)

- Open kernel module (`open = true`, RTX 30+ required)
- DRM modesetting, persistent mode, VA-API hardware decode
- 32-bit libs for Steam/Wine
- Wayland env vars set (`GBM_BACKEND`, `__GLX_VENDOR_LIBRARY_NAME`, etc.)
- CUDA + cuDNN stack via `hosts/common/optional/cuda.nix`

---

## Theme

**Gruvbox Material Dark** everywhere — Hyprland borders, Waybar, Kitty, tmux, Starship, btop, Zed, Zathura, fuzzel, GTK apps, Qt/Kvantum apps.

Palette: `#282828` bg · `#d4be98` fg · `#7daea3` teal · `#d8a657` yellow · `#ea6962` red · `#a9b665` green · `#d3869b` purple
