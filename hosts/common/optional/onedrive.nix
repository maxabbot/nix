# onedrive.nix — OneDrive sync via onedriver (FUSE, on-demand files). Run
# onedriver-launcher once per machine to add the account and mountpoint; it
# manages its own `onedriver@<mount>.service` user unit from there.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    onedriver
  ];
}
