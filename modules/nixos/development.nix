# modules/nixos/development.nix — Languages, containers, cloud tooling, and dev utilities.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.development;
in
{
  options.custom.development = {
    enable = lib.mkEnableOption "development toolchain";

    containers = {
      podman.enable = lib.mkEnableOption "Podman container runtime (with Docker compatibility)";
      libvirt.enable = lib.mkEnableOption "libvirt / QEMU-KVM virtualisation";
    };

    database = {
      guiClients.enable = lib.mkEnableOption "GUI database clients (DBeaver, Beekeeper, mycli, litecli)";
      dataPlatforms.enable = lib.mkEnableOption "data platform tools (DuckDB)";
    };

    cloudTools.enable = lib.mkEnableOption "cloud / infra CLIs (kubectl, helm, opentofu, AWS, Azure, GCP)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      with pkgs;
      [
        # Language runtimes
        python3
        python3Packages.pip
        python3Packages.virtualenv
        go
        rustup
        jdk
        gcc
        clang
        cmake
        gnumake

        # Data science (system Python packages)
        python3Packages.matplotlib
        python3Packages.numpy
        python3Packages.pandas
        python3Packages.scipy
        python3Packages.scikit-learn

        # Dev utilities
        shellcheck
        tig
        sqlite
        yq

        # Runtime managers (mise is user-scope in HM home.packages)
        uv
        quickemu
        quickgui

        # JS runtime
        bun

        # API tools
        curlie
        bruno

        # DB CLI clients (lightweight, always included)
        pgcli
      ]
      ++ lib.optionals cfg.containers.podman.enable [
        podman
        podman-compose
      ]
      ++ lib.optionals cfg.containers.libvirt.enable [
        libvirt
        qemu
        virt-manager
        dnsmasq
      ]
      ++ lib.optionals cfg.cloudTools.enable [
        kubectl
        kubectx
        kubernetes-helm
        opentofu
        awscli2
        azure-cli
        google-cloud-sdk
        doctl
      ]

      ++ lib.optionals cfg.database.guiClients.enable [
        dbeaver-bin
        beekeeper-studio
        mycli
        litecli
      ]
      ++ lib.optionals cfg.database.dataPlatforms.enable [
        duckdb
      ];

    # ── Podman ─────────────────────────────────────────────────────────────────
    virtualisation.podman = lib.mkIf cfg.containers.podman.enable {
      enable = true;
      dockerCompat = true; # provides `docker` → `podman` symlink
      defaultNetwork.settings.dns_enabled = true;
    };

    # ── libvirt / KVM ──────────────────────────────────────────────────────────
    virtualisation.libvirtd = lib.mkIf cfg.containers.libvirt.enable {
      enable = true;
      qemu.runAsRoot = false;
    };

    # ── direnv ─────────────────────────────────────────────────────────────────
    programs.direnv.enable = true;

    # ── SSH daemon ─────────────────────────────────────────────────────────────
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = true;
        PermitRootLogin = "no";
      };
    };
  };
}
