# pwas.nix — declarative "installed" web apps via Chrome's --app mode: each
# gets its own .desktop entry, taskbar icon, and chromeless window (no tabs/
# URL bar), sharing the default Chrome profile's login session. `icon` is a
# theme icon name (Papirus, the Stylix icon theme, ships Teams/Chat/WhatsApp/
# Outlook) or an absolute svg/png path for apps Papirus lacks (Immich).
{ pkgs, lib, ... }:
let
  immichLogo = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/immich-app/immich/v2.7.5/design/immich-logo.svg";
    hash = "sha256-36XvcE0HhUkUMGwMIkFzvaJxD4/A3/6314aQ9Y+YEaY=";
  };
  apps = [
    {
      name = "Teams";
      icon = "teams";
      url = "https://teams.microsoft.com/v2/";
    }
    {
      name = "Google Chat";
      icon = "google-chat";
      url = "https://chat.google.com/";
    }
    {
      name = "WhatsApp";
      icon = "whatsapp";
      url = "https://web.whatsapp.com/";
    }
    {
      name = "Outlook";
      icon = "ms-outlook";
      url = "https://outlook.office.com/mail/";
    }
    # Photo library on the homelab — tailnet-only, so Tailscale must be up.
    {
      name = "Immich";
      icon = immichLogo;
      url = "https://immich.lab.maxabbot.com/";
    }
  ];
  mkPwa =
    { name, url, icon }:
    pkgs.makeDesktopItem {
      name = "pwa-${lib.toLower (builtins.replaceStrings [ " " ] [ "-" ] name)}";
      desktopName = name;
      exec = "${pkgs.google-chrome}/bin/google-chrome-stable --app=${url}";
      inherit icon;
      categories = [ "Network" ];
    };
in
{
  environment.systemPackages = map mkPwa apps;
}
