{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    slack
    discord
    zoom-us
  ];
}
