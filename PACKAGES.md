# NixOS Module Reference

This file lists the key packages managed by each NixOS module in `modules/nixos/` and `modules/home/`.
All packages are from `nixpkgs/nixos-unstable` unless noted.

---

## base.nix

Core utilities, networking, filesystem tools, fonts, and system services.

| Package | Purpose |
|---------|---------|
| `coreutils`, `findutils`, `gnused`, `gnutar`, `bc` | POSIX base utils |
| `curl`, `wget`, `rsync`, `openssh`, `gnupg` | Transfer / remote access |
| `inetutils`, `dnsutils`, `traceroute`, `nethogs`, `iotop` | Networking diagnostics |
| `wireguard-tools`, `openvpn`, `networkmanagerapplet` | VPN / network management |
| `btrfs-progs`, `dosfstools`, `exfatprogs`, `p7zip`, `unzip`, `unrar`, `zip` | Filesystems / archives |
| `gparted`, `parted` | Disk partitioning |
| `xdg-utils`, `xdg-user-dirs`, `wl-clipboard`, `qt5.qtwayland`, `qt6.qtwayland` | Wayland / XDG |
| `git`, `git-lfs`, `bat`, `eza`, `fd`, `fzf`, `ripgrep`, `jq` | CLI essentials |
| `zsh`, `tmux`, `fastfetch`, `btop`, `delta`, `libnotify` | Shell / terminal tools |
| `lm_sensors`, `clamav` | Hardware monitoring / security |
| `man-db`, `man-pages`, `bash-completion` | Documentation |
| `nerd-fonts.jetbrains-mono`, `noto-fonts-emoji` | Fonts |

---

## development.nix

Languages, containers, cloud CLIs, and dev utilities.

| Package | Purpose |
|---------|---------|
| `python3`, `python3Packages.{pip,virtualenv,matplotlib,numpy,pandas,scipy,scikit-learn}` | Python + data science |
| `go`, `rustup`, `jdk`, `gcc`, `clang`, `cmake`, `gnumake` | Language runtimes / build tools |
| `kitty`, `direnv`, `shellcheck`, `tig`, `imagemagick`, `sqlite` | Dev utilities |
| `mise` | Runtime version manager |
| `curlie`, `bruno` | API clients |
| `pgcli` | DB CLI (always on) |
| `podman`, `podman-compose` *(opt-in)* | Container runtime |
| `libvirt`, `qemu`, `virt-manager`, `dnsmasq` *(opt-in)* | Virtualisation |
| `kubectl`, `kubectx`, `kubernetes-helm`, `opentofu`, `awscli2`, `azure-cli`, `google-cloud-sdk`, `doctl` *(opt-in)* | Cloud / infra CLIs |
| `dbeaver-bin`, `beekeeper-studio`, `mycli`, `litecli` *(opt-in)* | GUI DB clients |
| `duckdb` *(opt-in)* | Embedded analytics |

---

## editor.nix *(home module)*

Editors managed at the user level.

| Package | Purpose |
|---------|---------|
| `zed-editor` | Primary editor |
| `nano` | Terminal fallback editor |
| `programs.vscode` | Backup GUI editor (Gruvbox Material theme, vim keybindings) |

VSCode extensions: `jdinhlife.gruvbox`, `vscodevim.vim`, `esbenp.prettier-vscode`, `dbaeumer.vscode-eslint`, `ms-python.python`, `rust-lang.rust-analyzer`, `golang.go`, `jnoortheen.nix-ide`, `redhat.vscode-yaml`, `tamasfe.even-better-toml`, `pkief.material-icon-theme`

---

## productivity.nix

Desktop environment, audio, and GUI apps.

| Package / Service | Purpose |
|-------------------|---------|
| SDDM (Wayland) | Display manager |
| Hyprland / Sway | Wayland compositors (per-host) |
| PipeWire + WirePlumber + ALSA + JACK | Audio stack |
| `grim`, `slurp`, `swww`, `swayidle`, `swaynotificationcenter` | Wayland screenshot / wallpaper / idle |
| `wl-clipboard`, `cliphist`, `wl-paste` | Clipboard |
| `fuzzel` | App launcher |
| `waybar` | Status bar |
| `hyprlock`, `wlogout`, `nwg-look` | Lock / logout / appearance |
| `playerctl`, `brightnessctl`, `pavucontrol` | Media / brightness / audio |
| `gammastep`, `grimblast` | Night light / screenshot helper |
| `xfce.thunar`, `xfce.thunar-archive-plugin`, `file-roller` | File manager |
| `libreoffice-fresh`, `rnote`, `zathura`, `calibre`, `pdfarranger`, `onlyoffice-bin` | Office / documents |
| `masterpdfeditor` | PDF editor |
| `zen-browser` | Primary browser |
| `google-chrome` *(opt-in)* | Secondary browser |
| `thunderbird`, `element-desktop` | Comms (always on) |
| `slack`, `discord`, `zoom-us` *(opt-in)* | Extra comms |
| `obsidian`, `bitwarden-desktop` | Notes / passwords |
| `vlc`, `mpv`, `imv`, `mpvpaper` | Media playback |
| `gimp`, `inkscape`, `krita` *(opt-in)* | Creative apps |
| `obs-studio`, `shotcut`, `rustdesk`, `gpu-screen-recorder`, `losslesscut-bin` *(opt-in)* | Streaming / recording |
| `rclone` | Cloud sync |
| `nvtop`, `openrgb-with-all-plugins`, `glances` | Monitoring / RGB |
| `veracrypt` | Encryption |
| `kvantum`, `papirus-icon-theme`, `foot`, `syncthingtray`, `yazi` | Desktop helpers |
| Syncthing (service) | File sync daemon |
| Flatpak (service) | App sandboxing |

---

## nvidia.nix

NVIDIA driver stack (RTX 40-series target).

| Option / Package | Purpose |
|-----------------|---------|
| `hardware.nvidia.open = true` | Open kernel module (RTX 30+) |
| `hardware.nvidia.modesetting.enable` | DRM modesetting (required for Wayland) |
| `hardware.nvidia.nvidiaPersistenced` | Keep GPU awake between compute workloads |
| `hardware.nvidia.package = nvidiaPackages.stable` | Stable driver branch |
| `nvidia-vaapi-driver`, `libva`, `libva-utils` | VA-API hardware video decode |
| `vulkan-tools`, `vulkan-validation-layers` | Vulkan diagnostics |
| `hardware.graphics.enable32Bit` | 32-bit libs for Steam / Wine |
| `cuda_nvcc`, `cudnn`, `clinfo` *(opt-in)* | CUDA / cuDNN compute stack |
| Kernel params: `nvidia-drm.modeset=1` | Wayland DRM modesetting |
| Env vars: `GBM_BACKEND`, `__GLX_VENDOR_LIBRARY_NAME`, `LIBVA_DRIVER_NAME` | Wayland NVIDIA env |

---

## gaming.nix

Gaming platform and peripherals.

| Package / Option | Purpose |
|-----------------|---------|
| `programs.steam` (+ `gamescopeSession`, `proton-ge-bin`) | Steam + Proton GE |
| `programs.gamemode` (renice 10) | CPU governor for games |
| `programs.gamescope` | Micro-compositor for games |
| `mangohud` | In-game overlay |
| `wineWowPackages.staging`, `wine-mono`, `winetricks` | Wine compatibility |
| `dxvk` *(opt-in)* | DXVK / DX→Vulkan translation |
| `protonup-qt`, `protontricks`, `heroic`, `itch`, `goverlay`, `vkbasalt` | Gaming utilities |
| `vulkan-tools`, `vulkan-validation-layers`, `vulkan-loader`, `glmark2` | Vulkan / GPU tools |
| `joyutils` | Controller support |
| `obs-studio`, `moonlight-qt` *(opt-in)* | Game streaming |
| `boot.extraModulePackages = xpadneo` | Xbox controller kernel module |
| `hardware.graphics.enable32Bit` | 32-bit library support |
| `boot.kernel.sysctl vm.max_map_count` | Anti-cheat / large game support |
