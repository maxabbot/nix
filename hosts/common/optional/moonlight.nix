# Moonlight — the *client* half of game streaming: connects to an Apollo or
# Sunshine host and plays its output. No service, no listening socket, no
# firewall hole; it is a GUI application and nothing else.
#
# Split out of gaming-streaming.nix so a machine can receive a stream without
# also becoming a host. That distinction matters on the laptops: Apollo wants
# capSysAdmin and openFirewall, which is a reasonable trade on a desktop that
# sits on one trusted LAN and a bad one on a machine that joins whatever
# network is in front of it.
#
# gaming-streaming.nix imports this file, so hosts that stream *out* get the
# client too and nothing needs to import both.
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.moonlight-qt ];
}
