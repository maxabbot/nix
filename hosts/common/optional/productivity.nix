{
  config,
  lib,
  pkgs,
  inputs,
  zen-browser,
  ...
}:
let
  inherit (config.custom.base) username;
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
    # Surfaced in the Quickshell Settings "KDE Connect" tab via kdeconnect-cli.
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
    };
    # ── Flatpak ─────────────────────────────────────────────────────────────────
    flatpak.enable = true;
    # ── Misc services ───────────────────────────────────────────────────────────
    udev.packages = [ pkgs.openrgb-with-all-plugins ];
    gvfs.enable = true;
    tumbler.enable = true;
  };

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

  # ── SMART health bridge ───────────────────────────────────────────────────────
  # smartctl needs root (raw device access) but the Quickshell "Drives" panel
  # runs as the user. A root oneshot dumps a reduced health summary for the fixed
  # disks to /run/smart/summary.json (RuntimeDirectory → world-readable) every
  # 5 min; the panel just reads that file — no sudo/setuid in the UI path. SMART
  # attributes change slowly, so the timer latency is immaterial.
  systemd = {
    services.smart-status = {
      description = "Dump SMART health JSON for the Quickshell Drives panel";
      path = with pkgs; [
        smartmontools
        util-linux
        jq
      ];
      serviceConfig = {
        Type = "oneshot";
        RuntimeDirectory = "smart"; # /run/smart, mode 0755 (user-readable)
        RuntimeDirectoryPreserve = "yes"; # survive between oneshot runs
        ExecStart = pkgs.writeShellScript "smart-status" ''
          set -euo pipefail
          dir=/run/smart
          # One reduced record per fixed disk; skip removable/hotplug (those are
          # the panel's mount list, not the health list). smartctl exits non-zero
          # on benign status bits, so guard the per-disk pipe with `|| true`.
          {
            lsblk -dpno NAME,TYPE,RM,HOTPLUG | while read -r dev type rm hp; do
              [ "$type" = disk ] || continue
              [ "$rm" = 1 ] && continue
              [ "$hp" = 1 ] && continue
              name=$(basename "$dev")
              smartctl --json=c -H -A -i "$dev" 2>/dev/null \
                | jq -c --arg n "$name" '{
                    name:   $n,
                    model:  (.model_name // $n),
                    passed: (.smart_status.passed),
                    temp:   (.temperature.current // null),
                    wear:   (.nvme_smart_health_information_log.percentage_used // null)
                  }' || true
            done
          } | jq -sc '.' > "$dir/summary.json.tmp"
          mv "$dir/summary.json.tmp" "$dir/summary.json"
        '';
      };
    };

    timers.smart-status = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "5min";
      };
    };
  };

  # ── Wayland session variables ─────────────────────────────────────────────────
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  environment.systemPackages = with pkgs; [
    grim
    slurp
    satty
    zbar
    awww # wallpaper daemon — NOT "swww"
    wl-clipboard
    cliphist
    nwg-look
    hyprlock
    playerctl
    brightnessctl
    grimblast
    hyprpicker # eyedropper colour picker (Super+Shift+P → color-picker.sh)
    bemoji # fuzzel emoji/glyph picker (Super+. → emoji-picker.sh)
    ddcutil # external-monitor brightness over DDC/CI (Quickshell Display tab)
    smartmontools # smartctl — fixed-disk SMART health (smart-status service → Drives tab)
    pavucontrol
    pamixer
    pulseaudio
    easyeffects # PipeWire EQ / effects (driven from the Quickshell Audio tab)
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
    thunderbird
    element-desktop
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
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
    yazi
    quickshell
  ];

}
