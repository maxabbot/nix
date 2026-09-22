# Apollo (a Sunshine fork) — the *host* half of game streaming: encodes this
# machine's display and serves it to Moonlight clients.
#
# Desktop-only by intent. capSysAdmin and openFirewall are needed for capture
# and for the client to reach it, which is fine on a box that lives on one
# trusted LAN and is not on a laptop that joins arbitrary networks. Hosts that
# only need to *watch* a stream import moonlight.nix instead.
{ pkgs, inputs, ... }:
{
  imports = [
    inputs.apollo-flake.nixosModules."x86_64-linux".default
    # The client, so a streaming host can also connect to another one.
    ./moonlight.nix
  ];

  # obs-studio comes from streaming-tools.nix (imported alongside this module).
  services.apollo = {
    enable = true;
    package = inputs.apollo-flake.packages.x86_64-linux.default;
    capSysAdmin = true;
    openFirewall = true;
  };
}
