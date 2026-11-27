{
  config,
  lib,
  pkgs,
  inputs,
  machineType,
  ...
}:
let
  inherit (config.custom.base) username;
  hostSecrets = ../../../secrets/${config.networking.hostName}.yaml;
  hasIdentity = builtins.pathExists hostSecrets;
  # Hosts sharing the Obsidian vault over Syncthing (see folders.obsidian).
  # A host joins with an EMPTY ~/Obsidian — move any existing vault aside
  # first (`mv ~/Obsidian ~/Obsidian.old-sync`) so Syncthing fills it from the
  # homelab. Joining with an existing copy that has drifted turns every
  # differing file into a sync-conflict file.
  obsidianHosts = [
    "home-desktop"
    "framework"
  ];
  duxGreeterModule = "${inputs.nixpkgs-unstable}/nixos/modules/services/display-managers/dux-greeter.nix";

  # OnlyOffice runs on XWayland (nixpkgs forces QT_QPA_PLATFORM=xcb), and its
  # message boxes ("Save changes?") and file chooser are always native GTK3.
  # Under force_zero_scaling, Xft.dpi carries the scale (192 on framework's 2x
  # panel; see hyprland.nix), but the session's GDK_SCALE=1 left GTK drawing
  # 2x text inside 1x padding, icons and buttons: oversized and cramped. Match
  # GDK_SCALE to Xft.dpi at launch, halving GDK_DPI_SCALE so text isn't scaled
  # twice. It does nothing on a 1x host, and nothing at a fractional dpi, since
  # GDK_SCALE only takes whole numbers. The Qt editor window does its own
  # scaling and ignores both variables.
  onlyoffice =
    let
      pkg = pkgs.onlyoffice-desktopeditors;
    in
    pkgs.symlinkJoin {
      name = "onlyoffice-desktopeditors-gtk-scaled";
      paths = [ pkg ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/onlyoffice-desktopeditors --run '
          dpi=$(${lib.getExe pkgs.xrdb} -query 2>/dev/null | ${lib.getExe pkgs.gnused} -n "s/^Xft\.dpi:\s*//p")
          if [[ $dpi =~ ^[0-9]+$ ]] && (( dpi > 96 && dpi % 96 == 0 )); then
            export GDK_SCALE=$(( dpi / 96 ))
            export GDK_DPI_SCALE=$(${lib.getExe pkgs.gawk} "BEGIN { print 1 / $GDK_SCALE }")
          fi
        '
        # The desktop entries Exec the unwrapped binary by store path.
        for f in ${pkg}/share/applications/*.desktop; do
          rm "$out/share/applications/$(basename "$f")"
          sed "s|${pkg}/bin/|$out/bin/|g" "$f" > "$out/share/applications/$(basename "$f")"
        done
      '';
    };
in
{
  # DMS 2.1 split the greeter out of the shell into its own binary
  # (dux-greeter), so 26.05's dms-greeter module, which runs a script from
  # the shell's tree (Modules/Greetd/assets/dms-greeter), finds nothing and
  # greetd gives up after five instant exits. Swap in unstable's dux-greeter
  # module, minus its meta (it names lib.teams.duxlabs, which stable's lib
  # lacks). Drop both lines once nixpkgs stable carries dux-greeter.
  disabledModules = [ "services/display-managers/dms-greeter.nix" ];
  imports = [
    ({ pkgs, ... }@args: removeAttrs (import duxGreeterModule (args // { inherit pkgs; })) [ "meta" ])
  ];

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
    # Thunar keeps its preferences (view mode, etc.) in xfconf. Without the
    # daemon nothing persists, and HM's xfconf.settings has nowhere to write.
    xfconf.enable = true;
  };

  # ── KDE Connect and Syncthing ports ──────────────────────────────────────────
  # Phone integration, surfaced on the DMS bar and control centre by the
  # dankKDEConnect plugin; lan-mouse's clipboard hand-off rides on it too.
  # Installed below rather than with programs.kdeconnect, which opens 1714-1764
  # on every interface with no way to scope it. The desktop keeps them open
  # for LAN discovery. A laptop joins networks that aren't ours, so there they
  # are open on the tailnet only — and since broadcast discovery doesn't cross
  # Tailscale, its peers are added once by tailnet IP (KDE Connect → Add
  # devices by IP, on either side).
  #
  # Syncthing's 22000 (TCP, and UDP for QUIC) follows the same split, in place
  # of services.syncthing.openDefaultPorts, which opens it on every interface.
  # Its peers reach each other by tailnet name (the devices below), so its
  # discovery port 21027 isn't needed.
  networking.firewall =
    let
      kdeConnect = [
        {
          from = 1714;
          to = 1764;
        }
      ];
      ports = {
        allowedTCPPortRanges = kdeConnect;
        allowedUDPPortRanges = kdeConnect;
        allowedTCPPorts = [ 22000 ];
        allowedUDPPorts = [ 22000 ];
      };
    in
    if machineType == "laptop" then { interfaces.tailscale0 = ports; } else ports;

  services = {
    # ── Display manager (DMS greeter on greetd) ────────────────────────────────
    # unstable's dux-greeter module (imported above; the user, cache dir and
    # log tag keep the dms-greeter name): greetd runs the DMS greeter UI
    # inside its own short-lived Hyprland as the dms-greeter user. Before
    # each start greetd copies the user's DMS settings.json (so the Gruvbox
    # custom theme, which it also copies) and session.json into
    # /var/lib/dms-greeter. The greeter's background is the settings'
    # lockScreenWallpaperPath, so it matches the DMS lock (the lockWallpaper
    # hmArg).
    #
    # dux-greeter is pure Go with the QML baked in; it runs quickshell from
    # PATH, so it takes stable's quickshell like the shell does (the module's
    # default would read programs.dux-shell, which stable lacks).
    displayManager.dux-greeter = {
      enable = true;
      package = pkgs.unstable.dux-greeter;
      quickshell.package = pkgs.quickshell;
      configHome = "/home/${username}";
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
    # a laptop between cities, with an IP lookup as its own fallback. That wifi
    # source needs wpa_supplicant: iwd hosts import geoclue-iwd.nix, and a
    # host without wifi pins enableStatic (home-desktop).
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
      # Ports: the firewall block above (tailnet-only on the laptop).
      # Flake is authoritative, as on the homelab: GUI-added devices/folders
      # are reverted on rebuild. Device IDs are public, not secrets.
      overrideDevices = true;
      overrideFolders = true;
      settings = {
        # Every peer is on the tailnet and named below, so nothing needs
        # finding: no announcing this device to Syncthing's public discovery
        # servers or the local network, no relays, and no UPnP asking the
        # router to forward 22000 in from the internet.
        options = {
          globalAnnounceEnabled = false;
          localAnnounceEnabled = false;
          relaysEnabled = false;
          natEnabled = false;
        };
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
          # Both workstation IDs are stable: their cert/key live in sops
          # (secrets/<host>.yaml), so a reinstall rejoins as the same device.
          # Dialled by MagicDNS name like the homelab; with discovery off,
          # these are how the two find each other.
          home-desktop = {
            id = "SJMUANY-4V4KATR-SBM36YJ-XZET74T-RECLCYD-PNC6JXD-OSO4R4A-A4GEPQC";
            addresses = [
              "tcp://home-desktop:22000"
              "dynamic"
            ];
          };
          framework = {
            id = "TTXBUEW-AA4YQVU-DEC4GOP-2D7QAD7-VBN4F3X-RJPTKUL-JYUUDRO-7AEDPAN";
            addresses = [
              "tcp://framework:22000"
              "dynamic"
            ];
          };
        };
        folders.syncdrive = {
          path = "/home/${username}/SyncDrive";
          devices = [
            "homelab"
            "home-desktop"
            "framework"
          ];
        };
        # The Obsidian vault, replacing Obsidian Sync (nixos-homelab Plan.md
        # §12). A star with the homelab as hub: each device shares this folder
        # with the homelab only, never with another workstation. A host joins
        # through obsidianHosts, with its vault moved aside first (see there). Keep Obsidian Sync on until every device
        # that edits the vault is here, then switch it off on all of them at
        # once.
        folders.obsidian = lib.mkIf (lib.elem config.networking.hostName obsidianHosts) {
          path = "/home/${username}/Obsidian";
          devices = [ "homelab" ];
          # Same list as the homelab's. Patterns are per device, so this is
          # what keeps .git and the workspace files from leaving this host.
          ignorePatterns = [
            "// Per-device UI state, rewritten on every click: the main conflict source"
            "/.obsidian/workspace.json"
            "/.obsidian/workspace-mobile.json"
            "// The vault's local git history. Syncing .git between machines corrupts it"
            "/.git"
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

  # /dev/uinput for synthetic input (Solaar's diverted keys; theclicker emits
  # clicks through a virtual device). TAG+="uaccess" grants the active-session
  # user access. theclicker also reads the keyboard's evdev node, which takes
  # root, so `autoclick` runs it through sudo (see base.nix on "input").
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
    rnote
    # mpv + zathura come from Home Manager (programs.mpv / programs.zathura)
    calibre
    pdfarranger
    masterpdfeditor
    onlyoffice # GTK-scaled wrapper, above
    element-desktop
    # From unstable: 26.05's 1.13.7 left the window blank on Electron 43
    # (renderer_init: webFrame "reading 'defineProperty'"), so it was held on
    # EOL Electron 42. Unstable's 1.15.0 renders on its default Electron 43
    # (tested 2026-11-27). Back to stable once a release ships 1.15+.
    unstable.obsidian
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

  # Metric-compatible Calibri/Cambria replacements, so .docx files from Office
  # keep their layout in OnlyOffice. Merges with base.nix's fonts.packages.
  fonts.packages = with pkgs; [
    carlito
    caladea
  ];
}
