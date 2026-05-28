{
  lib,
  machineType,
  location,
  ...
}:
{
  services.gammastep = lib.mkIf (machineType != "server") {
    enable = true;
    provider = "manual";
    inherit (location) latitude longitude;
    temperature = {
      day = 6500;
      night = 3500;
    };
  };

  xdg.configFile = lib.mkIf (machineType != "server") {
    "wlogout/layout".source = ../../config/wlogout/layout;
    "wlogout/style.css".source = ../../config/wlogout/style.css;
  };
}
