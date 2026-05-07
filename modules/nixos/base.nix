# modules/nixos/base.nix — Core system packages, networking, fonts, and services.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.base;
in
{
  options.custom.base = {
    enable = lib.mkEnableOption "base system configuration";

    username = lib.mkOption {
      type = lib.types.str;
      default = "max";
      description = "Primary non-root username.";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "Pacific/Auckland";
      description = "System timezone (TZ database name).";
    };

    powerManagement = lib.mkOption {
      type = lib.types.enum [
        "power-profiles-daemon"
        "tlp"
      ];
      default = "power-profiles-daemon";
      description = "Power management daemon to use.";
    };

    btrfsSnapshots = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable BTRFS timeline snapshots via snapper.";
    };

    firewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the kernel firewall.";
    };
  };

  config = lib.mkIf cfg.enable {
    # ── Locale & timezone ──────────────────────────────────────────────────────
    time.timeZone = cfg.timezone;
    i18n.defaultLocale = "en_US.UTF-8";

    # ── Kernel ─────────────────────────────────────────────────────────────────
    boot.kernelPackages = pkgs.linuxPackages_latest;

    # ── Networking ─────────────────────────────────────────────────────────────
    networking.networkmanager.enable = true;
    networking.firewall.enable = cfg.firewall;

    # ── Bluetooth ──────────────────────────────────────────────────────────────
    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = true;
    services.blueman.enable = true;

    # ── Printing ───────────────────────────────────────────────────────────────
    services.printing.enable = true;

    # ── Time sync ──────────────────────────────────────────────────────────────
    services.timesyncd.enable = true;

    # ── Power management ───────────────────────────────────────────────────────
    services.power-profiles-daemon.enable = cfg.powerManagement == "power-profiles-daemon";

    services.tlp = lib.mkIf (cfg.powerManagement == "tlp") {
      enable = true;
      settings = {
        TLP_DEFAULT_MODE = "AC";
      };
    };

    # ── BTRFS snapshots ────────────────────────────────────────────────────────
    services.snapper = lib.mkIf cfg.btrfsSnapshots {
      configs.root = {
        SUBVOLUME = "/";
        ALLOW_GROUPS = [ "wheel" ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = "5";
        TIMELINE_LIMIT_DAILY = "7";
        TIMELINE_LIMIT_WEEKLY = "0";
        TIMELINE_LIMIT_MONTHLY = "0";
        TIMELINE_LIMIT_YEARLY = "0";
      };
    };

    # ── Security / auth ────────────────────────────────────────────────────────
    security.polkit.enable = true;
    security.rtkit.enable = true; # required by PipeWire real-time scheduling
    services.gnome.gnome-keyring.enable = true;

    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    # ── Firmware ───────────────────────────────────────────────────────────────
    hardware.enableAllFirmware = true;
    hardware.enableRedistributableFirmware = true;

    # ── Shell ──────────────────────────────────────────────────────────────────
    programs.zsh.enable = true;

    # ── Primary user ───────────────────────────────────────────────────────────
    users.users.${cfg.username} = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
        "audio"
        "video"
        "render"
        "input"
        "lp"
      ]
      ++ lib.optionals config.virtualisation.libvirtd.enable [
        "libvirtd"
        "kvm"
      ]
      ++ lib.optionals config.virtualisation.podman.enable [ "podman" ]
      ++ lib.optionals config.programs.steam.enable [ "gamemode" ];
      shell = pkgs.zsh;
    };

    # ── System packages ────────────────────────────────────────────────────────
    environment.systemPackages = with pkgs; [
      # Core utilities
      coreutils
      findutils
      gnused
      gnutar
      bc
      curl
      wget
      rsync
      openssh
      gnupg
      man-db
      man-pages
      bash-completion

      # Networking tools
      inetutils
      dnsutils
      traceroute
      nethogs
      iotop
      wireguard-tools
      openvpn
      networkmanagerapplet

      # Filesystem
      dosfstools
      exfatprogs
      btrfs-progs
      p7zip
      unzip
      unrar
      zip
      gparted
      parted

      # Wayland / display
      xdg-utils
      xdg-user-dirs
      wl-clipboard
      qt5.qtwayland
      qt6.qtwayland
      libsForQt5.qt5ct
      kdePackages.qt6ct

      # CLI essentials
      git
      git-lfs
      bat
      eza
      fd
      fzf
      ripgrep
      jq
      zsh
      tmux
      fastfetch
      btop
      delta
      libnotify

      # Security / monitoring
      lm_sensors
      clamav

      # upower — needed by Waybar battery module
    ];

    # ── Fonts ──────────────────────────────────────────────────────────────────
    fonts = {
      enableDefaultPackages = true;
      fontDir.enable = true;
      packages = with pkgs; [
        nerd-fonts.fira-code
        nerd-fonts.jetbrains-mono
        noto-fonts-color-emoji
      ];
    };

    # ── XDG portals (base — compositor modules add their own) ─────────────────
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      configPackages = [ pkgs.xdg-desktop-portal-gtk ];
    };

    # ── upower ─────────────────────────────────────────────────────────────────
    services.upower.enable = true;

    # ── Nix settings ───────────────────────────────────────────────────────────
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      download-buffer-size = 268435456; # 256 MiB
    };

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };
}
