# NixOS Module Reference

This file lists the key packages managed by each NixOS module in `modules/nixos/`.
All packages are from `nixpkgs/nixos-unstable` unless noted.

---

## base.nix

Core utilities, networking, filesystem tools, fonts, and system services.

| Package | Purpose |
|---------|---------|
| `coreutils`, `findutils`, `gnused`, `gnutar` | POSIX base utils |
| `curl`, `wget`, `rsync`, `openssh` | Transfer / remote access |
| `inetutils`, `dnsutils`, `wireguard-tools`, `openvpn` | Networking |
| `btrfs-progs`, `dosfstools`, `exfatprogs`, `parted` | Filesystems |
| `git`, `bat`, `eza`, `fd`, `fzf`, `ripgrep`, `jq` | CLI essentials |
| `fastfetch`, `btop`, `delta`, `tmux` | System info / terminal tools |
| `nerd-fonts.fira-code`, `nerd-fonts.jetbrains-mono` | Fonts |

---

## development.nix

Languages, editors, containers, cloud CLIs, database tools.

| Package | Purpose |
|---------|---------|
| `python3`, `go`, `rustup`, `jdk`, `gcc` | Language runtimes |
| `helix`, `vscode`, `zed-editor` | Editors |
| `podman` + `dockerCompat` | Containers |
| `kubectl`, `kubernetes-helm`, `opentofu`, `awscli2`, `azure-cli` | Cloud/infra |
| `pgcli`, `dbeaver-bin`, `beekeeper-studio`, `mycli`, `litecli` | DB clients |
| `duckdb` | Embedded analytics |
| `mise` | Runtime version manager |
| `curlie`, `bruno` | API clients |

---

## productivity.nix

Desktop environment, audio, and GUI apps.

| Package | Purpose |
|---------|---------|
| SDDM | Display manager |
| Hyprland / Sway | Wayland compositors |
| PipeWire + WirePlumber | Audio |
| `google-chrome`, `firefox`, `zen-browser` | Browsers |
| `thunderbird`, `element-desktop` | Comms |
| `thunar`, `libreoffice-fresh`, `obsidian` | Files / office |
| `vlc`, `spotify`, `gimp`, `inkscape` | Media / creative |
| `syncthing` | File sync |

---

## nvidia.nix

NVIDIA driver stack.

| Option | Purpose |
|--------|---------|
| `hardware.nvidia.open = true` | Open kernel module (RTX 30+) |
| `hardware.nvidia.nvidiaPersistenced` | Persistence service |
| `cudaPackages.*` | CUDA / cuDNN |
| `hardware.graphics.enable32Bit` | Steam / Wine 32-bit |

---

## gaming.nix

Gaming platform and peripherals.

| Package / Option | Purpose |
|-----------------|---------|
| `programs.steam.enable` | Steam |
| `programs.gamemode.enable` | CPU governor for games |
| `programs.mangohud.enable` | In-game overlay |
| `wineWowPackages.staging`, `wine-mono`, `winetricks` | Wine |
| `heroic`, `itch` | Alternative launchers |
| `xpadneo` | Xbox controller support |
| `hardware.graphics.enable32Bit` | 32-bit library support |
