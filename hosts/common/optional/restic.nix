# hosts/common/optional/restic.nix — nightly restic backup of the home folder
# to B2 (both hosts). Separate from restic-maintenance.nix, which only checks
# and prunes the homelab's repository and backs nothing up.
#
# ── Layout ────────────────────────────────────────────────────────────────────
#
# One bucket for the workstations, one repository per host at /<hostname>,
# each with its own password and its own B2 key. Nothing is shared between
# the hosts, so neither can read or damage the other's backups — provided the
# keys are restricted to their prefix (below).
#
# ── One-time setup (B2 web UI, then sops on home-desktop) ─────────────────────
#
# 1. Bucket `maxabbot-workstation-backup`, same settings as the homelab's
#    (nixos-homelab docs/phases.md, Phase 7): private, encryption off (restic
#    encrypts), Object Lock off, lifecycle rule with empty prefix and *days
#    till delete* 30. Versioning plus that rule is what makes a bad prune or a
#    compromised host recoverable: in B2 a delete is a hide that lives 30 days.
# 2. One application key per host: read and write, this bucket only, file name
#    prefix `<hostname>/`. Not a no-delete key — restic deletes its lock file
#    at the end of every run, so a key that cannot delete cannot back up. If
#    the first run fails with access denied on the bucket itself, the prefix
#    restriction is the suspect: recreate the key without it.
# 3. A healthchecks.io check per host: period 1 day, grace 2 days (a laptop
#    is off for a weekend).
# 4. `sops secrets/<hostname>.yaml` and add:
#
#      restic-workstation:
#        repo-password: <long random string — `openssl rand -base64 33`>
#        b2-backup: |
#          AWS_ACCESS_KEY_ID=<keyID>
#          AWS_SECRET_ACCESS_KEY=<applicationKey>
#        healthchecks-url: https://hc-ping.com/<uuid>
#
#    Do this BEFORE the first rebuild that imports this file: a secret missing
#    from the file fails activation. Keep a copy of the repo password outside
#    this machine (it is in sops, so in git, but that copy needs the admin key).
#
# The repository is created on the first run (`initialize`). Then restore
# something — `sudo restic-home snapshots`, `sudo restic-home restore latest
# --target /tmp/r --include ~/Documents` — because a backup nobody has
# restored from is a hypothesis.
#
# ── Pruning ───────────────────────────────────────────────────────────────────
#
# Each host prunes its own repository, monthly. The homelab keeps its delete
# key off the NUC, but its own docs say the key split is not what protects the
# data — versioning is — and a workstation pruning itself avoids copying every
# host's repo password onto home-desktop.
#
# AWS_* rather than B2_*: B2 is reached through its S3 endpoint, and the
# native-backend variables fail against an `s3:` URL with an error naming
# neither (same as restic-maintenance.nix).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  host = config.networking.hostName;
  user = config.custom.base.username;
  home = config.users.users.${user}.home;

  endpointHost = "s3.eu-central-003.backblazeb2.com";
  endpoint = "https://${endpointHost}";
  repository = "s3:${endpointHost}/maxabbot-workstation-backup/${host}";

  secrets = config.sops.secrets;
  hostSecrets = ../../../secrets/${host}.yaml;
  hc = secrets."restic-workstation/healthchecks-url".path;
  curl = "${pkgs.curl}/bin/curl";

  # A monitoring failure must never become a job failure.
  ping = suffix: ''
    ${curl} -fsS -m 20 --retry 3 --retry-delay 5 -o /dev/null \
      "$(cat ${lib.escapeShellArg hc})${suffix}" || true
  '';

  # A Persistent timer fires right after boot or resume, usually before the
  # network is up — and on the laptop, possibly before wifi has joined at all.
  # Wait up to five minutes for B2 to answer (any HTTP status counts) rather
  # than fail and page over a slow DHCP lease.
  waitForB2 = ''
    for _ in $(seq 1 20); do
      ${curl} -sS -m 10 -o /dev/null ${lib.escapeShellArg endpoint} && break
      sleep 15
    done
  '';

  # This is a gaming machine as well. Stay out of the way.
  quiet = {
    Nice = 19;
    CPUSchedulingPolicy = "idle";
    IOSchedulingClass = "idle";

    # root, so it can read every file, but nothing it can write outside its
    # cache and runtime directories (the module sets those).
    ProtectSystem = "strict";
    ProtectHome = "read-only";
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RestrictNamespaces = true;
    RestrictRealtime = true;
    LockPersonality = true;
    NoNewPrivileges = true;
    RestrictAddressFamilies = [
      "AF_INET"
      "AF_INET6"
      "AF_UNIX"
    ];
  };
in
{
  sops.secrets = {
    "restic-workstation/repo-password".sopsFile = hostSecrets;
    "restic-workstation/b2-backup".sopsFile = hostSecrets;
    "restic-workstation/healthchecks-url".sopsFile = hostSecrets;
  };

  # Unit restic-backups-home; `sudo restic-home …` is the repository with
  # its environment set (the module's createWrapper).
  services.restic.backups.home = {
    inherit repository;
    passwordFile = secrets."restic-workstation/repo-password".path;
    environmentFile = secrets."restic-workstation/b2-backup".path;
    initialize = true;

    paths = [ home ];
    extraBackupArgs = [
      # Skips anything with a CACHEDIR.TAG (Chromium/Electron caches, cargo
      # targets, …) without listing each one.
      "--exclude-caches"
      # Stays on /home's filesystem: the onedriver FUSE mount (onedrive.nix)
      # would otherwise pull the whole OneDrive down, and podman's btrfs
      # subvolumes are images, not data.
      "--one-file-system"
    ];

    # Re-downloadable, regenerable, or backed up elsewhere. Sized on
    # home-desktop 2026-11-26: without these the home folder is ~1.5 TB, with
    # them a few tens of GB.
    exclude = [
      "${home}/.cache"
      "${home}/.local/share/Trash"

      # Steam: 1.4 TB of games. Keep userdata (screenshots, per-game config,
      # saves for the games without Steam Cloud). Excluding the contents,
      # not the directory, is what lets the negation reach inside.
      "${home}/.local/share/Steam/*"
      "!${home}/.local/share/Steam/userdata"
      "${home}/Games"
      "${home}/.wine"
      "${home}/.local/share/umu"
      "${home}/.local/share/lutris/runners"
      "${home}/.local/share/goverlay"

      # Package/toolchain caches and container images.
      "${home}/.npm"
      "${home}/.gradle"
      "${home}/Android"
      "${home}/.local/share/containers"
      "${home}/.local/share/flatpak"
      "${home}/.var/app/*/cache"
      "${home}/.local/share/rembg"
      "${home}/.nv"
      "${home}/.debug"
      "${home}/.zoom"

      # Build output and dev environments, wherever they are.
      "node_modules"
      ".direnv"
      ".venv"
      "__pycache__"
      "result"
      "result-*"

      # Browser caches inside profiles (most carry no CACHEDIR.TAG).
      "Cache"
      "Code Cache"
      "GPUCache"
      "CacheStorage"
      "ScriptCache"

      # VM disks (WinBoat's guest lives wherever it was installed) and
      # install media.
      "*.qcow2"
      "*.vhdx"
      "*.iso"

      # Synced to the homelab, which backs it up from /mnt/data/syncthing.
      "${home}/SyncDrive"

      # Has another copy (asked 2026-11-26).
      "${home}/Old PC backup"
    ];

    # Daily, catching up after boot/resume (the module's default is daily +
    # Persistent; this adds the jitter).
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };

    backupPrepareCommand = ''
      ${waitForB2}
      ${ping "/start"}
    '';
    # ExecStopPost: runs on failure too, with systemd's $SERVICE_RESULT.
    backupCleanupCommand = ''
      if [ "$SERVICE_RESULT" = success ]; then
        ${ping ""}
      else
        ${ping "/fail"}
      fi
    '';
  };

  systemd.services.restic-backups-home.serviceConfig = quiet;

  # Monthly: apply retention, then read back 5% of the data. A failure pings
  # /fail on the backup's check; success pings nothing, so a working prune can
  # never mask a broken backup.
  systemd.services.restic-home-maintenance = {
    description = "restic: prune and check this workstation's repository";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    environment = {
      RESTIC_REPOSITORY = repository;
      RESTIC_PASSWORD_FILE = secrets."restic-workstation/repo-password".path;
      RESTIC_CACHE_DIR = "/var/cache/restic-backups-home";
    };
    serviceConfig = quiet // {
      Type = "oneshot";
      User = "root";
      EnvironmentFile = secrets."restic-workstation/b2-backup".path;
      CacheDirectory = "restic-backups-home";
      CacheDirectoryMode = "0700";
      PrivateTmp = true;
    };
    script = ''
      set -uo pipefail
      ${waitForB2}
      restic=${pkgs.restic}/bin/restic
      # A backup cut off by suspend leaves a stale lock, which blocks prune's
      # exclusive one. unlock removes only stale locks.
      if $restic unlock \
        && $restic forget --prune --retry-lock=30m \
          --keep-daily=7 --keep-weekly=4 --keep-monthly=6 \
        && $restic check --retry-lock=30m --read-data-subset=5%; then
        exit 0
      else
        rc=$?
        ${ping "/fail"}
        exit "$rc"
      fi
    '';
  };

  systemd.timers.restic-home-maintenance = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "monthly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
