# hosts/common/optional/fan2go.nix — declarative fan control (replaces fancontrol).
#
# Why fan2go over fancontrol: fancontrol point-samples coretemp every 10s, so it
# chased sub-second CPU package-temp spikes and made the fans hunt up and down.
# fan2go keeps a *moving average* of the temperature
# (tempRollingWindowSize × tempSensorPollingRate) and drives the curve off that
# smoothed value, so bursty load no longer ramps the fans — only sustained heat does.
#
# Hardware (Gigabyte board, it8628 super-I/O + coretemp; note the RAM spd5118
# sensors push coretemp to hwmon6, but fan2go matches by *platform name* so the
# hwmon index drift that bit fancontrol is irrelevant here):
#   it8628  pwm1/fan1 = radiator (AIO) fans   -> managed
#   it8628  pwm3/fan3 = case fans             -> managed
#   it8628  pwm4/fan4 = AIO pump (~2600 RPM constant, ignores PWM) -> left alone
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

  configFile = pkgs.writeText "fan2go.yaml" ''
    dbPath: /var/lib/fan2go/fan2go.db

    # ── Smoothing (the whole point) ─────────────────────────────────────────
    # Average the CPU temperature over the last 20 samples (20 × 1s = 20s) so
    # short bursts don't move the fans; only sustained heat does.
    tempSensorPollingRate: 1s
    tempRollingWindowSize: 20
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
      - id: radiator
        hwMon:
          platform: it8628
          rpmChannel: 1
          pwmChannel: 1
        neverStop: true
        curve: radiator_curve
      - id: case
        hwMon:
          platform: it8628
          rpmChannel: 3
          pwmChannel: 3
        neverStop: false
        curve: case_curve

    curves:
      # Radiator: quiet floor through idle/light load, full by ~82°C. A full-load
      # test held the package at 81°C with the radiator at only ~1744 RPM, so the
      # slow floor has ample thermal headroom. (Under all-core load the core
      # average tracks within a few degrees of the package sensor, so the same
      # steps hold; at idle the average sits well below every threshold anyway.)
      - id: radiator_curve
        linear:
          sensor: cpu_avg
          steps:
            - 50: 15%
            - 58: 20%
            - 70: 55%
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
      ExecStart = "${pkgs.fan2go}/bin/fan2go --config ${configFile} --no-style";
      StateDirectory = "fan2go";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
