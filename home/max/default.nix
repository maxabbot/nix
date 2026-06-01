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
    inherit compositor monitors nvidia;
  };

  home = {
    username = "max";
    homeDirectory = "/home/max";
    stateVersion = "24.11";
    # home-manager master (26.11) intentionally leads nixpkgs-unstable (26.05);
    # they're date-aligned and compatible, so silence the version-mismatch check.
    enableNixpkgsReleaseCheck = false;
  };
}
