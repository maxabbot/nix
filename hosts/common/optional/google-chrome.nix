{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.google-chrome ];

  # Settings → Languages: English (New Zealand) first, so sites are sent
  # Accept-Language en-NZ. ForcedLanguages pins these to the top of the list
  # (more can still be added below). Chrome's UI locale and date-box format
  # come from the system locale (en_NZ, base.nix) instead, which it maps to its
  # en-GB locale: dd/mm/yyyy. Merges with Stylix's BrowserThemeColor in the
  # same managed policy file.
  programs.chromium.extraOpts.ForcedLanguages = [
    "en-NZ"
    "en-GB"
    "en"
  ];
}
