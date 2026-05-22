{ pkgs, ... }:
{
  boot.plymouth = {
    enable = true;
    theme = "simple";
    themePackages = [
      (pkgs.stdenv.mkDerivation {
        pname = "plymouth-theme-simple";
        version = "1.0";
        src = ../../../config/plymouth/simple;
        installPhase = ''
          mkdir -p $out/share/plymouth/themes/simple
          cp -r * $out/share/plymouth/themes/simple/
          substituteInPlace $out/share/plymouth/themes/simple/simple.plymouth \
            --replace "@out@" "$out"
        '';
      })
    ];
  };

  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "splash"
    "loglevel=3"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
  ];
}
