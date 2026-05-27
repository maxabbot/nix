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
    latitude = location.latitude;
    longitude = location.longitude;
    temperature = {
      day = 6500;
      night = 3500;
    };
  };
}
