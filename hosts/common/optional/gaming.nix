{ config, pkgs, ... }:
{
  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = false;
      gamescopeSession.enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };
    gamemode = {
      enable = true;
      enableRenice = true;
      settings.general = {
        renice = 10;
        inhibit_screensaver = 1;
      };
    };
    gamescope.enable = true;
  };

  environment.systemPackages = with pkgs; [
    mangohud
    linuxConsoleTools
    protonup-qt
    protontricks
    heroic
    lutris
    itch
    goverlay
    vkbasalt
    vulkan-tools
    vulkan-validation-layers
    vulkan-loader
    glmark2
  ];

  boot.extraModulePackages = [ config.boot.kernelPackages.xpadneo ];
  hardware.graphics.enable32Bit = true;
  services.udev.packages = [ pkgs.steam ];

  boot.kernel.sysctl = {
    "vm.max_map_count" = 2147483642;
  };
}
