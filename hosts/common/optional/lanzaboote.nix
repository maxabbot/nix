# hosts/common/optional/lanzaboote.nix — Secure Boot via lanzaboote.
#
# Prerequisites before adding this to a host's imports:
#   1. sbctl create-keys
#   2. sbctl enroll-keys --microsoft   (or without --microsoft on non-Windows setups)
#   3. Enable Secure Boot in UEFI firmware (Setup Mode or Audit Mode)
#
# After nixos-rebuild switch, verify: sbctl verify && sbctl status
{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  environment.systemPackages = [ pkgs.sbctl ];

  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
  };
}
