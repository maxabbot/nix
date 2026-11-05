# hosts/common/optional/geoclue-iwd.nix — WiFi geolocation for iwd hosts
# (framework), so DMS's auto-located weather follows the laptop.
#
# GeoClue's wifi source only gets scans from wpa_supplicant's D-Bus API. Under
# iwd it sees no networks and falls back to GeoIP, and Spark's addresses all
# geolocate to Auckland. This bridge does the wifi lookup itself: iwd scans,
# the nearby BSSIDs go to BeaconDB (the provider GeoClue's wifi source is
# already pointed at), and the fix is written to /etc/geolocation, the file
# GeoClue's static source watches. GeoClue serves the most accurate source, so
# a ~50 m wifi fix beats the ~25 km GeoIP one.
#
# BeaconDB answering 404 (an area it doesn't know) deletes the file, handing
# back to GeoIP rather than holding a stale fix from somewhere else. No wifi or
# no network leaves the last fix alone. Runs every 10 minutes and whenever
# NetworkManager brings a connection up (arriving somewhere, resume).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  bridge = pkgs.writeShellApplication {
    name = "geoclue-iwd-bridge";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gawk
      iw
      iwd
      jq
    ];
    text = ''
      geo=/etc/geolocation

      mapfile -t ifaces < <(iw dev | awk '$1 == "Interface" { print $2 }')
      [[ ''${#ifaces[@]} -gt 0 ]] || exit 0

      # iwd drops scan results nl80211 would otherwise keep, so ask it for a
      # fresh scan and read the cache straight after. "Already scanning" and
      # "radio off" both fail here harmlessly.
      for i in "''${ifaces[@]}"; do
        iwctl station "$i" scan >/dev/null 2>&1 || true
      done
      sleep 5

      aps=$(for i in "''${ifaces[@]}"; do iw dev "$i" scan dump; done |
        awk '/^BSS / { b = substr($2, 1, 17) } /signal:/ { printf "%s %d\n", b, $2 }' |
        sort -u)
      # BeaconDB needs two or more APs; fewer is wifi off, not "somewhere new".
      [[ $(grep -c . <<<"$aps") -ge 2 ]] || exit 0

      req=$(jq -Rn '{considerIp: false, wifiAccessPoints: [inputs | split(" ") | {macAddress: .[0], signalStrength: (.[1] | tonumber)}]}' <<<"$aps")
      resp=$(curl -sS --max-time 15 -H 'Content-Type: application/json' -d "$req" \
        https://api.beacondb.net/v1/geolocate) || exit 0

      if jq -e '.location' >/dev/null <<<"$resp"; then
        # Rounded (~100 m, accuracy to 100 m) so signal jitter doesn't rewrite
        # the file — every rewrite makes GeoClue, and DMS's weather, re-fetch.
        new=$(jq -r '"\(.location.lat * 1000 | round / 1000)\n\(.location.lng * 1000 | round / 1000)\n0\n\([.accuracy / 100 | ceil * 100, 100] | max)"' <<<"$resp")
        [[ -f $geo && $(<"$geo") == "$new" ]] && exit 0
        tmp=$(mktemp /etc/.geolocation.XXXXXX)
        printf '%s\n' "$new" >"$tmp"
        chgrp geoclue "$tmp"
        chmod 0640 "$tmp"
        mv -f "$tmp" "$geo"
      elif [[ $(jq -r '.error.code // empty' <<<"$resp") == 404 ]]; then
        rm -f "$geo"
      fi
    '';
  };
in
{
  assertions = [
    {
      assertion = config.networking.wireless.iwd.enable && config.services.geoclue2.enable;
      message = "geoclue-iwd.nix bridges iwd scans into GeoClue; it needs both enabled.";
    }
  ];

  services.geoclue2 = {
    # The static source reads /etc/geolocation. enableStatic also switches the
    # other sources off; keep wifi, whose GeoIP fallback covers the gaps.
    enableStatic = true;
    enableWifi = lib.mkForce true;
    # Unused (the module's /etc/geolocation is disabled below) but typed.
    staticLatitude = 0.0;
    staticLongitude = 0.0;
  };
  # The bridge owns /etc/geolocation, not the module's read-only store copy.
  environment.etc.geolocation.enable = false;

  systemd.services.geoclue-iwd-bridge = {
    description = "Locate by nearby wifi (iwd + BeaconDB) for GeoClue";
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "iwd.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe bridge;
      PrivateTmp = true;
      ProtectHome = true;
      NoNewPrivileges = true;
    };
  };

  systemd.timers.geoclue-iwd-bridge = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "10min";
    };
  };

  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeShellScript "geoclue-iwd-bridge-on-up" ''
        [ "$2" = up ] && ${config.systemd.package}/bin/systemctl start --no-block geoclue-iwd-bridge.service
        exit 0
      '';
    }
  ];
}
