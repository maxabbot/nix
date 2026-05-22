# hosts/minimal/default.nix — Minimal headless / server profile (base only, no GUI).
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
  ];

  custom.base = {
    enable = true;
    username = "max";
    timezone = "UTC";
    initialPassword = "123"; # change after first login
    sshKeys = [ ]; # populate before relying on deploy.sh
    powerManagement = "power-profiles-daemon";
    firewall = true;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "minimal";

  system.stateVersion = "24.11";
}
