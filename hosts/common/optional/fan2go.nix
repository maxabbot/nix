# hosts/common/optional/fan2go.nix — declarative fan control (replaces fancontrol).
#
# Why fan2go over fancontrol: fancontrol point-samples coretemp every 10s, so it
# chased sub-second CPU package-temp spikes and made the fans hunt up and down.
# fan2go keeps a *moving average* of the temperature
# (tempRollingWindowSize × tempSensorPollingRate) and drives the curve off that
# smoothed value, so bursty load no longer ramps the fans — only sustained heat does.
#
# Hardware (Gigabyte Z790 UD AX, IT8689E super-I/O + coretemp; fan2go matches by
# *platform name*, so hwmon index drift is irrelevant). Mapped 2026-11-19 with
# per-channel sweeps against RPM and a microphone (only one ITE chip exists):
#   it8689  pwm3/fan3 = SYS_FAN2A/2B: the O11 Dynamic Mini V2 Flow's five case
#                       fans. Stop below PWM ~64, inaudible up to ~128 (~1275
#                       RPM), +3 dB at 160, +6 dB at 200          -> managed
#   it8689  pwm2/fan2 = SYS_FAN1: MasterLiquid 360L Core radiator fans (4-pin
#                       PWM). PWM 38 = 685 RPM (silent), 100 = 1019, 128 = 1180
#                       (just audible), 160 = 1347, 255 = 1748     -> managed
#   it8689  pwm4/fan4 = SYS_FAN3_PUMP: the AIO pump (whines at full) -> BIOS
#   it8689  pwm1/pwm5 = CPU_FAN / CPU_OPT: empty
# Every header needs the it87 driver from upstream PR #128 or later (pinned in
# hosts/home-desktop/default.nix). nixpkgs' 2025-12-26 build accepted pwmN
# writes on all headers but SYS_FAN2 and ignored them, because the BIOS kept
# control. The newer driver names the chip it8689_<SIV id>; the "it8689"
# platform match below still finds it.
#   coretemp temp2+   = per-core temps, averaged by the cpu-avg-temp script
#                       (temp1 = package sensor = peak core; deliberately unused)
#
# fan2go auto-calibrates each managed fan's min/start/max PWM on first run and
# stores it in dbPath. Expect a one-time fan ramp on the first boot after enabling
# while it measures; subsequent boots reuse /var/lib/fan2go.

{ pkgs, ... }:
let
  # Average of all per-core temps (coretemp temp2+; temp1 is the package sensor,
  # which reports the *hottest* core and spikes when any single core bursts).
  # Output is milli-degrees, as fan2go cmd sensors require. On read failure,
  # emit a high value so the fans fail toward full speed rather than silence.
  cpu-avg-temp = pkgs.writeShellScript "fan2go-cpu-avg" ''
    set -uo pipefail
    total=0 n=0
    for f in /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp*_input; do
      [ "''${f##*/}" = "temp1_input" ] && continue # package (peak) — skip
      read -r t < "$f" || continue
      total=$((total + t)) n=$((n + 1))
    done
    if [ "$n" -eq 0 ]; then
      echo 82000
      exit 0
    fi
    echo $((total / n))
  '';

  # The newer it87 driver reports any channel whose duty is 255 as mode 0 ("full
  # speed"), even in manual mode. fan2go then sees "PWM mode stuck to 0", and
  # the channel ends up rejecting pwm writes (EBUSY) until re-armed. fan2go's
  # calibration ends at 255, and a crashed run can leave a channel there, so
  # before each start put any channel reporting 0 back into manual at mid duty.
  # (maxPwm 254 on the fans keeps fan2go itself from writing 255.)
  unstick-pwm = pkgs.writeShellScript "fan2go-unstick-pwm" ''
    set -uo pipefail
    for name in /sys/class/hwmon/hwmon*/name; do
      read -r chip < "$name" || continue
      case "$chip" in it8689*) ;; *) continue ;; esac
      dir=''${name%/name}
      for ch in 2 3; do
        en="$dir/pwm''${ch}_enable"
        [ -w "$en" ] || continue
        read -r mode < "$en" || continue
        if [ "$mode" = 0 ]; then
          echo 1 > "$en"
          echo 128 > "$dir/pwm$ch"
        fi
      done
    done
  '';

  configFile = pkgs.writeText "fan2go.yaml" ''
    dbPath: /var/lib/fan2go/fan2go.db

    # ── Smoothing (the whole point) ─────────────────────────────────────────
    # Average the CPU temperature over the last 60 samples (60 × 1s = 60s) so
    # short bursts don't move the fans; only sustained heat does.
    tempSensorPollingRate: 1s
    tempRollingWindowSize: 60
    rpmPollingRate: 1s
    rpmRollingWindowSize: 10

    fanController:
      adjustmentTickRate: 500ms

    api:
      enabled: false
    statistics:
      enabled: false

    sensors:
      # Average across all cores rather than the package sensor — the package
      # value is the peak core and reads several degrees hotter under bursty
      # single-core load, even after the rolling-window smoothing.
      - id: cpu_avg
        cmd:
          exec: ${cpu-avg-temp}

    fans:
      # Not "radiator": fan2go keys its calibration DB by id, and that id holds
      # stale data from an old pwm1 entry, so a fresh id recalibrates.
      - id: radiator_fans
        hwMon:
          platform: it8689
          rpmChannel: 2
          pwmChannel: 2
        neverStop: true
        maxPwm: 254 # 255 reads back as mode 0 (see unstick-pwm)
        curve: radiator_curve
      - id: case
        hwMon:
          platform: it8689
          rpmChannel: 3
          pwmChannel: 3
        neverStop: false
        curve: case_curve

    curves:
      # Radiator: ~685 RPM (measured silent) through a sustained 60°C, ~1000 RPM
      # (still below the room) by 70°C, full by 82°C. A full-load test held the
      # package at 81°C with these fans near their 1750 RPM max, so the top end
      # stays where it was.
      - id: radiator_curve
        linear:
          sensor: cpu_avg
          steps:
            - 60: 15%
            - 70: 40%
            - 78: 70%
            - 82: 100%
      # Case fans: off until warm, spin up under sustained load.
      - id: case_curve
        linear:
          sensor: cpu_avg
          steps:
            - 55: 0%
            - 68: 30%
            - 82: 100%
  '';
in
{
  environment.systemPackages = [ pkgs.fan2go ];

  systemd.services.fan2go = {
    description = "fan2go temperature-based fan control";
    documentation = [ "https://github.com/markusressel/fan2go" ];
    wantedBy = [ "multi-user.target" ];
    after = [ "sysinit.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStartPre = unstick-pwm;
      ExecStart = "${pkgs.fan2go}/bin/fan2go --config ${configFile} --no-style";
      StateDirectory = "fan2go";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
