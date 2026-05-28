{ pkgs, ... }:
{
  boot = {
    plymouth = {
      enable = true;
      theme = "spin";
      themePackages = [
        (pkgs.adi1090x-plymouth-themes.override {
          selected_themes = [ "spin" ];
        })
      ];
    };
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
  };
}
