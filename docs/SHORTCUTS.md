# Shortcuts Reference

All navigation follows vim-style `hjkl` movement. Modifier keys: `Super` (WM), `Ctrl+A` prefix (tmux), `Space` leader (nvim).

---

## Window Manager (Sway / Hyprland)

| Key | Action |
|-----|--------|
| `Super+Return` | Terminal (kitty) |
| `Super+D` | Launcher (fuzzel) |
| `Super+B` | Browser |
| `Super+E` | File manager (thunar) |
| `Super+Q` | Kill window |
| `Super+F` | Fullscreen |
| `Super+V` | Toggle floating |
| `Super+Space` | Focus tiling/floating |
| `Super+T` / `Super+Shift+T` | Split horizontal / vertical |
| `Super+H/J/K/L` | Focus window |
| `Super+Shift+H/J/K/L` | Move window |
| `Super+Ctrl+H/J/K/L` | Resize window (Hyprland) |
| `Super+R` | Resize mode (Sway) |
| `Super+1–0` | Switch workspace |
| `Super+Shift+1–0` | Move window to workspace |
| `Super+S` | Toggle scratchpad |
| `Super+Shift+S` | Move to scratchpad |
| `Super+L` | Lock screen |
| `Super+Shift+E` | Power menu |
| `Super+C` | Clipboard history |
| `Print` | Screenshot to clipboard (selection) |
| `Shift+Print` | Screenshot to clipboard (fullscreen) |
| `Super+Print` | Screenshot to file |
| `Super+Shift+G` | Toggle gaming mode (Hyprland) |
| `Super+Shift+R` | Reload config (Sway) |
| `XF86Audio*` | Volume / media controls |
| `XF86MonBrightness*` | Brightness |

---

## Tmux (prefix: `Ctrl+A`)

| Key | Action |
|-----|--------|
| `<prefix>+C` | New window |
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

## Neovim (leader: `Space`)

### Navigation

| Key | Action |
|-----|--------|
| `Ctrl+H/J/K/L` | Navigate windows |
| `Ctrl+arrows` | Resize windows |
| `Shift+L` / `Shift+H` | Next / previous buffer |
| `<leader>bd` | Delete buffer |

### Files & Search

| Key | Action |
|-----|--------|
| `<leader>e` | Toggle file explorer |
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Buffers |
| `<leader>fh` | Help tags |
| `<leader>fr` | Recent files |

### Splits & Tabs

| Key | Action |
|-----|--------|
| `<leader>sv` / `sh` | Vertical / horizontal split |
| `<leader>se` | Equalize splits |
| `<leader>sx` | Close split |
| `<leader>to` | New tab |
| `<leader>tx` | Close tab |
| `<leader>tn` / `tp` | Next / previous tab |

### LSP

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gr` | References |
| `gi` | Implementation |
| `gt` | Type definition |
| `K` | Hover docs |
| `<leader>ca` | Code actions |
| `<leader>rn` | Rename |
| `<leader>d` | Show diagnostics |
| `[d` / `]d` | Prev / next diagnostic |
| `<leader>fm` | Format |
| `<leader>rs` | Restart LSP |

### Git & Terminal

| Key | Action |
|-----|--------|
| `<leader>gg` | LazyGit |
| `<leader>gb` | Toggle line blame |
| `<leader>tt` | Open terminal |
| `Esc` (terminal) | Exit terminal mode |

### Completion

| Key | Action |
|-----|--------|
| `Ctrl+K/J` | Prev / next item |
| `Ctrl+B/F` | Scroll docs |
| `Ctrl+Space` | Trigger completion |
| `Ctrl+E` | Abort |
| `Enter` | Confirm |
| `Tab` / `Shift+Tab` | Navigate / expand snippet |

---

## Helix (leader: `Space`)

| Key | Action |
|-----|--------|
| `Ctrl+S` | Save file |
| `Space+f` | File picker |
| `Space+b` | Buffer picker |
| `Space+/` | Global search |
| `Space+w` | Write |
| `Space+q` | Quit |

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

## Foot Terminal

| Key | Action |
|-----|--------|
| `Ctrl+Shift+C` | Copy |
| `Ctrl+Shift+V` | Paste |
| `Ctrl+Shift+R` | Search |
| `Ctrl++` / `Ctrl+-` / `Ctrl+0` | Font size up / down / reset |

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

### Editor
```
v / vi / vim  →  hx (Helix)
```

### Pacman / AUR
```
pacup     →  sudo pacman -Syu
pacin     →  sudo pacman -S
pacrem    →  sudo pacman -Rns
pacsearch →  pacman -Ss
yayup     →  yay -Syu
yayin     →  yay -S
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
gc  →  git commit   gcm →  git commit -m
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
| `sysup` | Update pacman + yay + rustup |
| `fcd` | Fuzzy cd with fzf |
| `qfind <pattern>` | Quick find by filename |
| `psgrep <name>` | Search processes |
| `dclean` | Podman system cleanup |
