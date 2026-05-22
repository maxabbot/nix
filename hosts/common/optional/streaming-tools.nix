{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    obs-studio
    shotcut
    rustdesk
    gpu-screen-recorder
    losslesscut-bin
  ];
}
