# pwas.nix — declarative "installed" web apps via Chrome's --app mode: each
# gets its own .desktop entry, taskbar icon, and chromeless window (no tabs/
# URL bar), sharing the default Chrome profile's login session. `icon` falls
# back to a generic one; swap in a real per-app icon later by pointing it at
# an absolute svg/png path.
{ pkgs, lib, ... }:
let
  apps = [
    {
      name = "Teams";
      url = "https://teams.microsoft.com/v2/";
    }
    {
      name = "Google Chat";
      url = "https://chat.google.com/";
    }
    {
      name = "WhatsApp";
      url = "https://web.whatsapp.com/";
    }
    {
      name = "Outlook";
      url = "https://outlook.office.com/mail/";
    }
  ];
  mkPwa =
    { name, url }:
    pkgs.makeDesktopItem {
      name = "pwa-${lib.toLower (builtins.replaceStrings [ " " ] [ "-" ] name)}";
      desktopName = name;
      exec = "${pkgs.google-chrome}/bin/google-chrome-stable --app=${url}";
      icon = "web-browser";
      categories = [ "Network" ];
    };
in
{
  environment.systemPackages = map mkPwa apps;
}
