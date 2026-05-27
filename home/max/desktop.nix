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
}
