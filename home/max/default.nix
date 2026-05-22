{
  compositor,
  monitors,
  inputs,
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

  custom.hm.compositor = compositor;
  custom.hm.monitors = monitors;

  home = {
    username = "max";
    homeDirectory = "/home/max";
    stateVersion = "24.11";
  };
}
