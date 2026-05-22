{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    dbeaver-bin
    beekeeper-studio
    mycli
    litecli
  ];
}
