{
  compositor,
  monitors,
  inputs,
  nvidia ? false,
  ...
}:
{
  imports = [
    ../../modules/home/default.nix
    ./git.nix
    ./cli.nix
    ./desktop.nix
    ./packages.nix
    inputs.nix-index-database.homeModules.nix-index
  ];

  custom.hm = {
    compositor = compositor;
    monitors = monitors;
    nvidia = nvidia;
  };

  home = {
    username = "max";
    homeDirectory = "/home/max";
    stateVersion = "24.11";
  };
}
