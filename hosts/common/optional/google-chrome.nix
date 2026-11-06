{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.google-chrome ];

  # Settings → Languages: English (New Zealand) first, so sites are sent
  # Accept-Language en-NZ. ForcedLanguages pins these to the top of the list
  # (more can still be added below). This alone doesn't change date boxes on
  # Linux — that's the LANGUAGE wrapper in overlays/default.nix. Merges with
  # Stylix's BrowserThemeColor in the same managed policy file.
  programs.chromium.extraOpts.ForcedLanguages = [
    "en-NZ"
    "en-GB"
    "en"
  ];
}
