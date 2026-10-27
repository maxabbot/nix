# lan-mouse — software KVM: share one keyboard/mouse between home-desktop and
# the framework (Wayland-native; uses Hyprland's InputCapture portal).
#
# This file only opens the event port. The package, config.toml and the user
# daemon live in home/max/lan-mouse.nix, parameterised by the `lanMouse` hmArgs
# set in flake.nix (peer hostname + which screen edge the peer sits on).
#
# lan-mouse 0.10 sends input events over plain unauthenticated UDP, so anyone
# who can reach the port can type into the machine. It's opened on tailscale0
# only: the peers find each other by MagicDNS name, the traffic rides
# WireGuard, and only this tailnet's own devices can reach it. On the LAN the
# two still talk directly, since Tailscale picks the direct path.
{ config, ... }:
{
  assertions = [
    {
      assertion = config.services.tailscale.enable;
      message = "lan-mouse.nix opens its port on tailscale0 only; import tailscale.nix as well.";
    }
  ];

  networking.firewall.interfaces.tailscale0.allowedUDPPorts = [ 4242 ];
}
