# lan-mouse — software KVM: share one keyboard/mouse between home-desktop and
# work-laptop over the LAN (Wayland-native; uses Hyprland's InputCapture portal).
#
# This file only opens the event port. The package, config.toml and the user
# daemon live in home/max/lan-mouse.nix, parameterised by the `lanMouse` hmArgs
# set in flake.nix (peer hostname + which screen edge the peer sits on).
#
# NOTE: lan-mouse 0.10 sends input events over plain unauthenticated UDP —
# trusted LAN only. Re-evaluate when nixpkgs picks up a release with the
# certificate-based authentication.
_: {
  networking.firewall.allowedUDPPorts = [ 4242 ];
}
