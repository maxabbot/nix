# Custom package overlays — add local derivations or override upstream packages.
# Each attribute is available as pkgs.<name> throughout the entire flake.
final: prev: {
  wine-ge-custom = final.callPackage ../pkgs/wine-ge-custom { };

  # nixpkgs still ships 0.10.7; 1.0.0 adds frame-rate-independent smoothing and
  # better PipeWire error handling. Drop this override once nixpkgs catches up.
  cava = prev.cava.overrideAttrs (old: rec {
    version = "1.0.0";
    src = final.fetchFromGitHub {
      owner = "karlstav";
      repo = "cava";
      rev = version;
      hash = "sha256-0vQWobnt9pAZTJc45Lgcfad72BE8DUPGQ5/YwMSmU98=";
    };
  });
}
