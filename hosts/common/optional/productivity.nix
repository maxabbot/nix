{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (config.custom.base) username;
  hostSecrets = ../../../secrets/${config.networking.hostName}.yaml;
  hasIdentity = builtins.pathExists hostSecrets;
in
{
  imports = [ inputs.silentSDDM.nixosModules.default ];

  # Dedicated PAM service for hyprlock — without it, unlock falls back to
  # /etc/pam.d/su (works, but logs an error and skips e.g. fprint integration).
  security.pam.services.hyprlock = { };

  programs = {
    # ── Hyprland ────────────────────────────────────────────────────────────────
    # Using nixpkgs' hyprland module and package avoids referencing the flake's
    # source tarball at evaluation time (which breaks nix flake check).
    hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };

    # KDE Connect — phone integration (daemon + firewall ports 1714-1764).
    # Surfaced on the DMS bar and control centre by the dankKDEConnect plugin.
    kdeconnect.enable = true;

    silentSDDM = {
      enable = true;
      theme = "gruvbox";

      backgrounds = {
        wallpaper = ../../../config/sddm/leaves-wall.png;
      };

      settings = {
        # ── Background — gruvbox preset has use-background-color = true which
        # overrides the image; must explicitly disable it here.
        "LoginScreen" = {
          background = "leaves-wall.png";
          use-background-color = false;
          blur = 8;
        };
        "LockScreen" = {
          background = "leaves-wall.png";
          use-background-color = false;
          blur = 28;
        };

        # ── Login panel — right side so wallpaper is visible ──────────────────
        "LoginScreen.LoginArea" = {
          position = "right";
        };

        # ── Lock screen clock — 24h ───────────────────────────────────────────
        "LockScreen.Clock" = {
          format = "HH:mm";
        };
        "LockScreen.Date" = {
          locale = "en_NZ";
        };

      };
    };
  };

  services = {
    # ── Display manager (SDDM via SilentSDDM) ──────────────────────────────────
    # silentSDDM module handles enable/theme/extraPackages/QML2_IMPORT_PATH.
    # Do NOT use sugar-dark — it depends on Qt5 QtGraphicalEffects which
    # doesn't exist in Qt6 (SDDM 0.21+). Stylix has no SDDM target.
    # Do NOT set wayland.compositor — the nixpkgs default ("weston") handles
    # mouse/keyboard correctly in VMs; kwin is GPU-heavy and breaks input.
    # kdePackages.breeze must be in extraPackages so breeze_cursors is findable
    # on disk — silentSDDM's module only ships its own propagatedBuildInputs.
    displayManager.sddm = {
      extraPackages = [ pkgs.kdePackages.breeze ];
      settings = {
        Theme = {
          CursorTheme = "breeze_cursors";
          CursorSize = "24";
        };
        # ── Greeter cursor (the actual fix) ────────────────────────────────────
        # The KWin greeter compositor draws the pointer, but SDDM starts it
        # through sddm-helper, which RESETS the environment and injects ONLY the
        # string in sddm.conf's [General] GreeterEnvironment. Neither the systemd
        # unit's env nor sddm.extraPackages reaches KWin — so it can't find
        # breeze_cursors and logs "Unable to load any cursor theme", drawing
        # nothing. (kcminputrc below supplies the theme NAME; this supplies the
        # search PATH to the files.)
        # silentSDDM's module hardcodes GreeterEnvironment (QML2_IMPORT_PATH +
        # QT_IM_MODULE), so mkForce over it, re-adding those two and appending
        # the cursor vars. QML2_IMPORT_PATH uses the stable /run/current-system
        # symlink.
        General.GreeterEnvironment = lib.mkForce (
          lib.concatStringsSep "," [
            "QML2_IMPORT_PATH=/run/current-system/sw/share/sddm/themes/silent/components/"
            "QT_IM_MODULE=qtvirtualkeyboard"
            "XCURSOR_PATH=${pkgs.kdePackages.breeze}/share/icons"
            "XCURSOR_THEME=breeze_cursors"
            "XCURSOR_SIZE=24"
            "KWIN_FORCE_SW_CURSOR=1"
          ]
        );
      };
    };
    # ── PipeWire audio stack ────────────────────────────────────────────────────
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };
    pulseaudio.enable = false;
    # ── Syncthing ───────────────────────────────────────────────────────────────
    syncthing = {
      enable = true;
      user = username;
      dataDir = "/home/${username}";
      configDir = "/home/${username}/.config/syncthing";
      # Reproducible device ID: the host's cert/key come from sops when
      # secrets/<hostname>.yaml exists (home-desktop, framework); other hosts
      # generate their own on first start. One keypair per host — two hosts
      # sharing a cert would be a single device.
      cert = lib.mkIf hasIdentity config.sops.secrets."syncthing/cert-pem".path;
      key = lib.mkIf hasIdentity config.sops.secrets."syncthing/key-pem".path;
      openDefaultPorts = true; # 22000 sync + 21027/udp LAN discovery
      # Flake is authoritative, as on the homelab: GUI-added devices/folders
      # are reverted on rebuild. Device IDs are public, not secrets.
      overrideDevices = true;
      overrideFolders = true;
      settings = {
        devices = {
          # ID derived from the homelab's sops-held cert; its ID is stable across
          # reinstalls. Reached by MagicDNS over the tailnet (nixos-homelab repo).
          homelab = {
            id = "KPU5JYT-SBB4ZNY-QQGQ6YN-ML5MWOH-ZIT6D55-3W4GUCV-NAQCO73-LSKHQAT";
            addresses = [
              "tcp://homelab:22000"
              "dynamic"
            ];
          };
          home-desktop.id = "SJMUANY-4V4KATR-SBM36YJ-XZET74T-RECLCYD-PNC6JXD-OSO4R4A-A4GEPQC";
          # Both workstation IDs are stable: their cert/key live in sops
          # (secrets/<host>.yaml), so a reinstall rejoins as the same device.
          framework.id = "TTXBUEW-AA4YQVU-DEC4GOP-2D7QAD7-VBN4F3X-RJPTKUL-JYUUDRO-7AEDPAN";
        };
        folders.syncdrive = {
          path = "/home/${username}/SyncDrive";
          devices = [
            "homelab"
            "home-desktop"
            "framework"
          ];
        };
      };
    };
    # ── Flatpak ─────────────────────────────────────────────────────────────────
    flatpak.enable = true;
    # ── Misc services ───────────────────────────────────────────────────────────
    udev.packages = [ pkgs.openrgb-with-all-plugins ];
    gvfs.enable = true;
    tumbler.enable = true;
  };

  sops.secrets = lib.mkIf hasIdentity (
    lib.genAttrs [ "syncthing/cert-pem" "syncthing/key-pem" ] (_: {
      sopsFile = hostSecrets;
      owner = username;
      mode = "0400";
    })
  );

  # ~/SyncDrive — the one folder Syncthing shares (add it in the GUI or under
  # services.syncthing.settings.folders). Created here so it exists on every host.
  systemd.tmpfiles.rules = [ "d /home/${username}/SyncDrive 0755 ${username} users -" ];

  # KWin reads cursor theme/size from kcminputrc, not from sddm.conf [Theme].
  system.activationScripts.sddmCursorConfig = {
    deps = [ "users" ];
    text = ''
      mkdir -p /var/lib/sddm/.config
      printf '[Mouse]\ncursorTheme=breeze_cursors\ncursorSize=24\n' \
        > /var/lib/sddm/.config/kcminputrc
      chown sddm:sddm /var/lib/sddm/.config/kcminputrc
    '';
  };

  # /dev/uinput for synthetic input (theclicker autoclicker emits clicks through a
  # virtual device). TAG+="uaccess" grants the active-session user access; the
  # primary user is also in the "input" group (base.nix) to read the keyboard.
  hardware.uinput.enable = true;

  # ── Wayland session variables ─────────────────────────────────────────────────
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  environment.systemPackages = with pkgs; [
    grim
    awww # wallpaper daemon — NOT "swww"
    wl-clipboard
    nwg-look
    hyprlock
    playerctl
    brightnessctl
    hyprpicker # eyedropper colour picker (Super+Shift+P → color-picker.sh)
    bemoji # fuzzel emoji/glyph picker (Super+. → emoji-picker.sh)
    ddcutil # external-monitor brightness over DDC/CI (DMS brightness slider)
    xorg.xrandr # marks the XWayland primary output (hyprland.lua setXPrimary)
    smartmontools # smartctl — fixed-disk SMART health
    pavucontrol
    pamixer
    pulseaudio
    easyeffects # PipeWire EQ / effects
    hypridle
    thunar
    thunar-archive-plugin
    file-roller
    libreoffice-fresh
    rnote
    # mpv + zathura come from Home Manager (programs.mpv / programs.zathura)
    calibre
    pdfarranger
    masterpdfeditor
    onlyoffice-desktopeditors
    element-desktop
    obsidian
    bitwarden-desktop
    vlc
    imv
    mpvpaper
    rclone
    nvtopPackages.full
    openrgb-with-all-plugins
    glances
    veracrypt
    kdePackages.qtstyleplugin-kvantum
    papirus-icon-theme
    quickshell # DMS's runtime — `dms run` finds it on PATH
    theclicker # autoclicker CLI (x11/wayland, evdev/uinput); wrapped as `autoclick`
  ];

}
