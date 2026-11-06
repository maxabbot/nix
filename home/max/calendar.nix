# home/max/calendar.nix — dcal (Dux Calendar), the calendar behind DMS's clock
# popout.
#
# dcal syncs the accounts and serves them to DMS over a socket in
# $XDG_RUNTIME_DIR; DMS's calendarBackend is pinned to it in
# modules/home/wm/dms.nix (left on "auto" it falls back to khal, absent here).
# Accounts are per-machine state, added once on each workstation — never in
# Nix, since they carry OAuth tokens and passwords:
#
#   dcal account add caldav      personal calendars, the homelab's Radicale
#                                (https://dav.lab.maxabbot.com, tailnet-only;
#                                nixos-homelab hosts/common/optional/radicale.nix)
#   dcal account add microsoft   work (Outlook), read from Microsoft directly
#
# dux-calendar is unstable-only (2.0, released with DMS 2.0).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  dcal = pkgs.unstable.dux-calendar;
in
lib.mkIf (config.custom.hm.compositor != "none") {
  home.packages = [ dcal ];

  # The package's own lib/systemd/user/dcal.service, restated so Home Manager
  # enables it: session-managed, window hidden until opened from DMS.
  systemd.user.services.dcal = {
    Unit = {
      Description = "Dux Calendar";
      Documentation = "https://github.com/duxlabs-dev/dux-calendar";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      StartLimitIntervalSec = 60;
      StartLimitBurst = 5;
    };
    Service = {
      ExecStart = "${lib.getExe' dcal "dcal"} run --session --hidden";
      Restart = "on-failure";
      RestartSec = 2;
      Slice = "app.slice";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
