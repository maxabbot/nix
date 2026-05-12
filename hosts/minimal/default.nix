# hosts/minimal/default.nix — Minimal headless / server profile (base only, no GUI).
{
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
  ];

  custom.base = {
    enable = true;
    username = "max";
    timezone = "UTC";
    firewall = true;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "minimal";

  system.stateVersion = "24.11";
}
