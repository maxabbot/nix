# No `? default`s in this signature: HM resolves these args before signature
# defaults could apply, so every one is set in sharedHmArgs (flake.nix).
{
  compositor,
  monitors,
  inputs,
  nvidia,
  wallpaper,
  wallpaperPortrait,
  lockWallpaper,
  kanshi,
  ...
}:
{
  imports = [
    ../../modules/home/default.nix
    ./calendar.nix
    ./claude.nix
    ./git.nix
    ./cli.nix
    ./desktop.nix
    ./lan-mouse.nix
    ./libreoffice.nix
    ./packages.nix
    ./terminal-toys.nix
    ./tui-themes.nix
    inputs.nix-index-database.homeModules.nix-index
  ];

  custom.hm = {
    inherit
      compositor
      monitors
      nvidia
      kanshi
      wallpaper
      wallpaperPortrait
      lockWallpaper
      ;
  };

  home = {
    username = "max";
    homeDirectory = "/home/max";
    stateVersion = "24.11";
  };
}
