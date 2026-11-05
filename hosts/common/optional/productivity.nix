{
  config,
  lib,
  pkgs,
  machineType,
  ...
}:
let
  inherit (config.custom.base) username;
  hostSecrets = ../../../secrets/${config.networking.hostName}.yaml;
  hasIdentity = builtins.pathExists hostSecrets;

  # ── DMS greeter package ─────────────────────────────────────────────────────
  # The launcher (Modules/Greetd/assets/dms-greeter) ends its compositor with
  # `hyprctl dispatch exit`, the hyprlang form, which Hyprland on Lua rejects.
  # The greeter's Hyprland would then never exit, and greetd only starts the
  # session once the greeter has gone. A store-path script sidesteps the
  # quoting: the call sits inside a Lua string inside `sh -c "…"`.
  greeterExit = pkgs.writeShellScript "dms-greeter-exit" ''
    exec ${config.programs.hyprland.package}/bin/hyprctl dispatch 'hl.dsp.exit()'
  '';
  dmsGreeter = pkgs.dms-shell.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      substituteInPlace "$out/share/quickshell/dms/Modules/Greetd/assets/dms-greeter" \
        --replace-fail 'hyprctl dispatch exit' ${greeterExit}
    '';
  });

  # The greeter reads a fixed-name override from its data dir; configFiles
  # copies by basename, so the file has to carry that name. The leaves are the
  # desktop's default wallpaper too (sharedHmArgs).
  greeterWallpaper =
    pkgs.runCommand "dms-greeter-wallpaper" { nativeBuildInputs = [ pkgs.imagemagick ]; }
      ''
        mkdir -p $out
        magick ${../../../config/wallpapers/leaves-wall.png} $out/greeter_wallpaper_override.jpg
      '';
in
{
  # Password PAM service for the DMS lock screen. DMS uses /etc/pam.d/dankshell
  # when it exists; without it, it writes its own copy of the login stack into
  # ~/.local/state on first lock, which would drift from the system's.
  security.pam.services.dankshell = { };

  programs = {
    # ── Hyprland ────────────────────────────────────────────────────────────────
    # Using nixpkgs' hyprland module and package avoids referencing the flake's
    # source tarball at evaluation time (which breaks nix flake check).
    hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };
  };

  # ── KDE Connect ───────────────────────────────────────────────────────────────
  # Phone integration, surfaced on the DMS bar and control centre by the
  # dankKDEConnect plugin; lan-mouse's clipboard hand-off rides on it too.
  # Installed below rather than with programs.kdeconnect, which opens 1714-1764
  # on every interface with no way to scope it. The desktop keeps them open
  # for LAN discovery. A laptop joins networks that aren't ours, so there they
  # are open on the tailnet only — and since broadcast discovery doesn't cross
  # Tailscale, its peers are added once by tailnet IP (KDE Connect → Add
  # devices by IP, on either side).
  networking.firewall =
    let
      kdeConnect = {
        allowedTCPPortRanges = [
          {
            from = 1714;
            to = 1764;
          }
        ];
        allowedUDPPortRanges = kdeConnect.allowedTCPPortRanges;
      };
    in
    if machineType == "laptop" then { interfaces.tailscale0 = kdeConnect; } else kdeConnect;

  services = {
    # ── Display manager (DMS greeter on greetd) ────────────────────────────────
    # nixpkgs' dms-greeter module: greetd runs the DMS greeter UI inside its own
    # short-lived Hyprland as the dms-greeter user. Before each start greetd
    # copies the user's DMS settings.json (so the Gruvbox custom theme, which
    # it also copies) and session.json into /var/lib/dms-greeter.
    displayManager.dms-greeter = {
      enable = true;
      package = dmsGreeter;
      configHome = "/home/${username}";
      configFiles = [ "${greeterWallpaper}/greeter_wallpaper_override.jpg" ];
      compositor = {
        name = "hyprland";
        # Lua (Hyprland 0.55): the launcher spots `hl.` and appends the start
        # hook that runs the greeter, but leaves the rest — DMS_RUN_GREETER,
        # the logo — to a custom config. Hosts append monitor rules. The
        # cursor is Stylix's, as in the session; the greeter user's
        # environment has no XCURSOR_PATH of its own.
        customConfig = ''
          hl.env("DMS_RUN_GREETER", "1")
          hl.env("XCURSOR_PATH", "${config.stylix.cursor.package}/share/icons")
          hl.env("XCURSOR_THEME", "${config.stylix.cursor.name}")
          hl.env("XCURSOR_SIZE", "${toString config.stylix.cursor.size}")
          hl.config({
              misc = {
                  disable_hyprland_logo = true,
              },
          })
        '';
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
    # ── Location (DMS weather) ─────────────────────────────────────────────────
    # DMS's auto-location asks GeoClue2 first and falls back to ip-api.com,
    # which times out from some networks — then the weather widget never
    # loads. GeoClue locates by nearby wifi APs (BeaconDB), which also follows
    # a laptop between cities, with an IP lookup as its own fallback.
    geoclue2.enable = true;
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

  # /dev/uinput for synthetic input (theclicker autoclicker emits clicks through a
  # virtual device). TAG+="uaccess" grants the active-session user access; the
  # primary user is also in the "input" group (base.nix) to read the keyboard.
  hardware.uinput.enable = true;

  # ── Wayland session variables ─────────────────────────────────────────────────
  # (Firefox-based browsers default to Wayland, so no MOZ_ENABLE_WAYLAND.)
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # wl-clipboard comes from base.nix.
  environment.systemPackages = with pkgs; [
    grim
    awww # wallpaper daemon — NOT "swww"
    nwg-look
    playerctl
    brightnessctl
    hyprpicker # eyedropper colour picker (Super+Shift+P → color-picker.sh)
    ddcutil # external-monitor brightness over DDC/CI (DMS brightness slider)
    xrandr # marks the XWayland primary output (hyprland.lua setXPrimary)
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
    # .full drags in the whole CUDA toolkit (~10 GiB) for its NVIDIA backend,
    # so only the NVIDIA host gets it; the Intel-only hosts get the Intel build.
    (
      if lib.elem "nvidia" config.services.xserver.videoDrivers then
        nvtopPackages.full
      else
        nvtopPackages.intel
    )
    glances
    veracrypt
    kdePackages.qtstyleplugin-kvantum
    papirus-icon-theme
    quickshell # DMS's runtime — `dms run` finds it on PATH
    kdePackages.kdeconnect-kde # firewall above
    theclicker # autoclicker CLI (x11/wayland, evdev/uinput); wrapped as `autoclick`
  ];

}
