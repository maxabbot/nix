# hosts/common/optional/restic-maintenance.nix — verify and prune the homelab's
# restic repository on B2. Never backs anything up. home-desktop only.
#
# The NUC (nixos-homelab repo) pushes a nightly `restic backup` to B2. This is
# the other half of that repository's lifecycle: `restic check` to prove the
# data is still readable, and `restic forget --prune` to apply retention. It
# used to run on a Raspberry Pi; the Pi was retired on 2026-11-17 (see Plan.md
# §12 in nixos-homelab) and the job moved here.
#
# ── Why it is not on the NUC ──────────────────────────────────────────────────
#
# `forget --prune` deletes data, and the key it needs (`restic/b2-prune`) can
# empty the bucket. Keeping that key off the server that faces the network is
# the whole design: a compromised NUC can at worst hide objects, which bucket
# versioning keeps for 30 days. nixos-homelab's restic-backup.nix asserts that
# the NUC never runs maintenance. This file is where it runs instead.
#
# ── Why the schedule is loose ─────────────────────────────────────────────────
#
# A workstation is not on at 3am. Both timers are Persistent, so a missed run
# fires on the next boot (or resume); the check is weekly and the prune
# monthly, which is plenty for a repository that only grows by one snapshot a
# night. The dead-man's switch is the healthchecks.io check that used to watch
# the Pi — set its period to 7 days with a few days' grace. If this machine is
# off for longer than that, it will page, and that is correct: nothing else is
# checking the backups.
#
# ── Must match the NUC ────────────────────────────────────────────────────────
#
# `repository` and `restic/repo-password` must be identical to nixos-homelab's
# `resticRepository` (hosts/homelab/services.nix) and `restic.repo-password`
# (secrets/homelab.yaml). One repository, two machines.
#
# Credentials are AWS_* in an environment file: B2 is reached through its S3
# endpoint, and B2_ACCOUNT_ID/B2_ACCOUNT_KEY (the native `b2:` backend) fail
# against an `s3:` URL with an error that names neither. Do not make the key
# no-delete "append-only" and do not put Object Lock on the objects: restic
# writes and deletes a lock file every run, so either breaks it outright.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  repository = "s3:s3.eu-central-003.backblazeb2.com/maxabbot-homelab-backup";
  endpoint = "https://s3.eu-central-003.backblazeb2.com";

  secrets = config.sops.secrets;

  mkResticScript =
    name: args:
    pkgs.writeShellScript "restic-${name}" ''
      set -uo pipefail

      export RESTIC_REPOSITORY=${lib.escapeShellArg repository}
      export RESTIC_PASSWORD_FILE=${lib.escapeShellArg secrets."restic/repo-password".path}
      export RESTIC_CACHE_DIR="$CACHE_DIRECTORY"

      hc="$(cat ${lib.escapeShellArg secrets."restic/healthchecks-url".path})"
      ping() {
        # A monitoring failure must never become a job failure.
        ${pkgs.curl}/bin/curl -fsS -m 20 --retry 3 --retry-delay 5 \
          -o /dev/null "$hc$1" || true
      }

      # A Persistent timer fires right after boot or resume, often before the
      # network is really up, and network-online.target means little on a
      # workstation. Wait up to five minutes for B2 to answer at all (any HTTP
      # status counts) before treating it as a failure, so a slow DHCP lease
      # does not page as a broken backup.
      for _ in $(seq 1 20); do
        ${pkgs.curl}/bin/curl -sS -m 10 -o /dev/null ${lib.escapeShellArg endpoint} && break
        sleep 15
      done

      ping "/start"
      if ${pkgs.restic}/bin/restic ${lib.concatStringsSep " " args}; then
        ping ""
        exit 0
      else
        rc=$?
        ping "/fail"
        exit "$rc"
      fi
    '';

  serviceConfig = {
    Type = "oneshot";
    User = "root";
    EnvironmentFile = secrets."restic/b2-prune".path;

    CacheDirectory = "restic";
    CacheDirectoryMode = "0700";

    # This is a gaming machine as well. Stay out of the way.
    Nice = 19;
    CPUSchedulingPolicy = "idle";
    IOSchedulingClass = "idle";

    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
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

  unitDeps = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
in
{
  sops.secrets = {
    "restic/repo-password".sopsFile = ../../../secrets/home-desktop.yaml;
    "restic/b2-prune".sopsFile = ../../../secrets/home-desktop.yaml;
    "restic/healthchecks-url".sopsFile = ../../../secrets/home-desktop.yaml;
  };

  systemd = {
    services.restic-check = unitDeps // {
      description = "restic: verify the homelab repository";
      serviceConfig = serviceConfig // {
        ExecStart = mkResticScript "check" [
          "check"
          # 5% of pack data read back each week: the whole repository roughly
          # every five months, well inside B2's free egress.
          "--read-data-subset=5%"
          # The NUC holds the lock while it backs up (02:30 plus jitter).
          "--retry-lock=30m"
        ];
      };
    };

    services.restic-prune = unitDeps // {
      description = "restic: apply retention to the homelab repository";
      serviceConfig = serviceConfig // {
        ExecStart = mkResticScript "prune" [
          "forget"
          "--prune"
          # Same policy the Pi ran (nixos-homelab restic-maintenance.nix defaults).
          "--keep-daily=7"
          "--keep-weekly=5"
          "--keep-monthly=12"
          "--keep-yearly=3"
          "--group-by=host,paths"
          "--retry-lock=30m"
        ];
      };
    };

    timers.restic-check = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    timers.restic-prune = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "monthly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };

  # `sudo restic-repo snapshots`, `sudo restic-repo restore latest --target …`:
  # the repository with its environment already set up. A backup nobody has
  # restored from is a hypothesis.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "restic-repo" ''
      set -euo pipefail
      if [ "$(id -u)" -ne 0 ]; then
        echo "restic-repo must run as root (the credentials are root-only)." >&2
        exit 1
      fi
      set -a
      . ${lib.escapeShellArg secrets."restic/b2-prune".path}
      set +a
      export RESTIC_REPOSITORY=${lib.escapeShellArg repository}
      export RESTIC_PASSWORD_FILE=${lib.escapeShellArg secrets."restic/repo-password".path}
      export RESTIC_CACHE_DIR=/var/cache/restic
      exec ${pkgs.restic}/bin/restic "$@"
    '')
  ];
}
