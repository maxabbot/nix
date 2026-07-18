# lan-mouse — software KVM between home-desktop and work-laptop.
# Enabled per-host via the `lanMouse` hmArgs in flake.nix; the firewall port
# is opened by hosts/common/optional/lan-mouse.nix on the same hosts.
#
# The daemon starts with the graphical session but the peer is NOT active on
# startup (activateOnStartup = false), so nothing captures input until you
# activate the peer in the GUI (`lan-mouse`) or CLI (`lan-mouse-cli`). Flip
# activateOnStartup in flake.nix once the link is confirmed working.
#
# If capture is ever stuck on the other machine, the release bind is the
# default: LeftCtrl+LeftShift+LeftMeta+LeftAlt pressed together.
{
  lib,
  pkgs,
  # Defaulted in flake.nix sharedHmArgs — a `? {...}` default here would be
  # ignored (the module system resolves args before signature defaults apply).
  lanMouse,
  ...
}:
{
  config = lib.mkIf lanMouse.enable {
    home.packages = [ pkgs.lan-mouse ];

    # lan-mouse resolves hostnames with its own DNS client (reads
    # resolv.conf directly, bypassing NSS) — so avahi/.local names won't
    # work. If the router doesn't resolve DHCP hostnames, set
    # lanMouse.ips = [ "192.168.x.x" ] for the peer in flake.nix.
    xdg.configFile."lan-mouse/config.toml".source =
      (pkgs.formats.toml { }).generate "lan-mouse-config.toml"
        {
          port = 4242;
          ${lanMouse.position} = {
            hostname = lanMouse.peer;
            activate_on_startup = lanMouse.activateOnStartup or false;
            # Clipboard hand-off: when the cursor crosses to the peer, push this
            # machine's clipboard to it over KDE Connect (paired via
            # productivity.nix's programs.kdeconnect; device name = hostname).
            # Fails soft (logged by the daemon) if the peer isn't paired yet.
            enter_hook = "${lib.getExe' pkgs.kdePackages.kdeconnect-kde "kdeconnect-cli"} --send-clipboard --name ${lanMouse.peer}";
          }
          // lib.optionalAttrs (lanMouse ? ips) { inherit (lanMouse) ips; };
        };

    # Mirrors the upstream service/lan-mouse.service unit.
    systemd.user.services.lan-mouse = {
      Unit = {
        Description = "Lan Mouse input sharing daemon";
        After = [ "graphical-session.target" ];
        BindsTo = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${lib.getExe pkgs.lan-mouse} --daemon";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
