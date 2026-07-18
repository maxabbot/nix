{
  lib,
  machineType,
  location,
  ...
}:
{
  xdg.desktopEntries = {
    sunshine = {
      name = "Sunshine";
      noDisplay = true;
      exec = "sunshine";
    };
    "dev.lizardbyte.app.Sunshine" = {
      name = "Sunshine";
      noDisplay = true;
      exec = "sunshine";
    };
    "dev.lizardbyte.app.Sunshine.terminal" = {
      name = "Sunshine (terminal)";
      noDisplay = true;
      exec = "sunshine";
    };
  };

  services.gammastep = lib.mkIf (machineType != "server") {
    enable = true;
    provider = "manual";
    inherit (location) latitude longitude;
    temperature = {
      day = 6500;
      night = 3500;
    };
  };

}
