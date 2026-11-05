{
  osConfig,
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

  services.gammastep = {
    enable = true;
    provider = "manual";
    # The system location (base.nix), shared with Clight.
    inherit (osConfig.location) latitude longitude;
    temperature = {
      day = 6500;
      night = 3500;
    };
  };

}
