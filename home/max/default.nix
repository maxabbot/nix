{
  compositor,
  monitors,
  inputs,
  nvidia ? false,
  kanshi ? {
    enable = false;
  },
  ...
}:
{
  imports = [
    ../../modules/home/default.nix
    ./git.nix
    ./cli.nix
    ./desktop.nix
    ./lan-mouse.nix
    ./packages.nix
    ./terminal-toys.nix
    inputs.nix-index-database.homeModules.nix-index
  ];

  custom.hm = {
    inherit
      compositor
      monitors
      nvidia
      kanshi
      ;
  };

  home = {
    username = "max";
    homeDirectory = "/home/max";
    stateVersion = "24.11";
  };
}
