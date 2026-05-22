# Shortcuts Reference

All navigation follows vim-style `hjkl` movement. Modifier keys: `Super` (WM), `Ctrl+A` prefix (tmux), `Space` leader (nvim).

---

## Window Manager (Hyprland)

| Key | Action |
|-----|--------|
| `Super+Return` | Terminal (kitty) |
| `Super+D` | App launcher (fuzzel) |
| `Super+B` | Browser (Chrome) |
| `Super+E` | File manager (thunar) |
| `Super+Q` | Kill window |
| `Super+Shift+Q` | Exit Hyprland |
| `Super+F` | Fullscreen |
| `Super+Shift+F` | Maximize (keep decorations) |
| `Super+V` | Toggle floating |
| `Super+P` | Toggle pseudo-tile |
| `Super+T` | Toggle split direction (dwindle) |
| `Super+H/J/K/L` | Focus window |
| `Super+Shift+H/J/K/L` | Move window |
| `Super+Ctrl+H/J/K/L` | Resize window |
| `Super+1–0` | Switch workspace |
| `Super+Shift+1–0` | Move window to workspace |
| `Super+S` | Toggle scratchpad |
| `Super+Shift+S` | Move to scratchpad |
| `Super+L` | Lock screen |
| `Super+Shift+L` | Suspend |
| `Super+Shift+E` | Power menu (wlogout) |
| `Super+N` | Notifications (swaync) |
| `Super+Shift+V` | Clipboard history (cliphist) |
| `Print` | Screenshot to clipboard (selection) |
| `Shift+Print` | Screenshot to clipboard (fullscreen) |
| `Super+Print` | Screenshot to file |
| `Super+Shift+G` | Toggle gaming mode |
| `XF86Audio*` | Volume / media controls |
| `XF86MonBrightness*` | Brightness |

---

## Tmux (prefix: `Ctrl+A`)

| Key | Action |
|-----|--------|
| `<prefix>+c` | New window |
| `<prefix>+\|` | Split horizontal |
| `<prefix>+-` | Split vertical |
| `<prefix>+H/J/K/L` | Navigate panes |
| `<prefix>+Shift+H/J/K/L` | Resize pane (5px) |
| `<prefix>+F` | Fuzzy project switcher (tmux-sessionizer) |
| `<prefix>+R` | Reload config |
| `<prefix>+[` | Enter copy mode |
| `V` (copy mode) | Begin selection |
| `Y` (copy mode) | Copy and exit |

**Shell:** `Ctrl+F` — open tmux-sessionizer from any prompt.

---

## Zsh

| Key | Action |
|-----|--------|
| `Ctrl+F` | tmux-sessionizer |
| `Ctrl+T` | Fuzzy file finder (fzf) |
| `Ctrl+R` | Fuzzy history search (fzf) |
| `Alt+C` | Fuzzy cd (fzf) |
| `↑` / `↓` | History substring search |

---

## Yazi (file manager)

| Key | Action |
|-----|--------|
| `E` | Open with… |
| `F` | Filter (fuzzy) |
| `.` | Toggle hidden files |
| `T` | New tab (current dir) |
| `Tab` / `Shift+Tab` | Next / previous tab |

---

## Zathura (PDF viewer)

| Key | Action |
|-----|--------|
| `H` / `L` | Previous / next page |
| `D` / `U` | Scroll half-down / half-up |
| `K` / `J` | Zoom in / out |
| `R` | Rotate |
| `Ctrl+R` | Reload |

---

## Kitty Terminal

| Key | Action |
|-----|--------|
| `Ctrl+Shift+C` | Copy |
| `Ctrl+Shift+V` | Paste |
| `Ctrl+Shift+F` | Search |
| `Ctrl+Shift+=` / `Ctrl+Shift+-` / `Ctrl+Shift+Backspace` | Font size up / down / reset |

---

## Shell Aliases

### Navigation
```
..  →  cd ..          ...  →  cd ../..
```

### Files (eza)
```
ls   →  eza (icons + color)
ll   →  eza -la (git status, icons)
lt   →  eza -aT --level=2 (tree)
cat  →  bat --paging=never
less →  bat --paging=always
```

### NixOS
```
nixup    →  nh os switch /etc/nixos
nixsrch  →  nix search nixpkgs
nixshell →  nix shell nixpkgs#<pkg>
nixtmp   →  nix-shell -p <pkg>
gcclean  →  sudo nix-collect-garbage -d && sudo nix store optimise
flkupd   →  nix flake update
```

### Systemd
```
srestart  →  sudo systemctl restart
sstatus   →  sudo systemctl status
senable   →  sudo systemctl enable
sdisable  →  sudo systemctl disable
jctl      →  journalctl -xe
```

### Git
```
g   →  git          gs  →  git status
ga  →  git add      gaa →  git add --all
gc  →  git commit -v   gcm →  git commit -m
gp  →  git push     gpl →  git pull
gd  →  git diff     gl  →  git log --oneline --graph
gco →  git checkout gb  →  git branch
```

### Podman
```
d / p   →  podman          dc   →  podman-compose
dps     →  podman ps        dpsa →  podman ps -a
dim     →  podman images    dex  →  podman exec -it
dlog    →  podman logs -f
```

### Languages
```
py / py3 →  python3         venv     →  python -m venv
c        →  cargo           cb/cr/ct →  cargo build/run/test
nr       →  npm run         ni       →  npm install
```

### Safety
```
rm / cp / mv  →  interactive (-i flag)
```

---

## Shell Functions

| Function | Description |
|----------|-------------|
| `mkcd <dir>` | Create and enter directory |
| `extract <file>` | Extract any archive format |
| `gcl <url>` | Git clone and cd |
| `mkvenv [name]` | Create and activate Python venv |
| `serve [port]` | Start HTTP server (default 8000) |
| `sysup` | Full system update: `nixup` + `rustup update` |
| `fcd` | Fuzzy cd with fzf |
| `qfind <pattern>` | Quick find by filename |
| `psgrep <name>` | Search processes |
| `dclean` | Podman system cleanup |
