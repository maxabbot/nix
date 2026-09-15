# Tailscale — joins the host to the tailnet. The servers repo is moving every
# service except SSH to Tailscale-only, so any host that uses those needs this.
#
# No secrets management yet, so there's no authKeyFile — log in once by hand
# after the first rebuild:
#   sudo tailscale up --operator=max
{ config, ... }:
{
  services.tailscale = {
    enable = true;
    # Open the WireGuard port (41641/udp) so peers connect directly instead of
    # being relayed through DERP.
    openFirewall = true;
    # Accept subnet routes / exit nodes advertised by the servers. Also relaxes
    # checkReversePath to "loose" so the rpfilter doesn't drop that traffic.
    useRoutingFeatures = "client";
    # Let the primary user run `tailscale up/down` without sudo — the Quickshell
    # Control Center tile shells out to exactly that.
    extraSetFlags = [ "--operator=${config.custom.base.username}" ];
  };

  # MagicDNS: without systemd-resolved, tailscaled overwrites /etc/resolv.conf
  # directly and NetworkManager (dns = "default") writes it back. With resolved,
  # tailscaled registers split DNS on tailscale0 and NM feeds it the LAN servers.
  services.resolved = {
    enable = true;
    # avahi already answers mDNS on 5353; don't run a second responder.
    settings.Resolve.MulticastDNS = false;
  };
}
