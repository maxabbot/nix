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
    hashedPassword = "$y$j9T$2U13TXbQqrmp.PD068E0E.$1uJPVe1dF1C0KhlXbn.iMg2qthRxOdp.9s/h6GG6YC6";
    sshKeys = [ ]; # populate before relying on deploy.sh
    powerManagement = "power-profiles-daemon";
    firewall = true;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "minimal";

  system.stateVersion = "24.11";
}
