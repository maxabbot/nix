# Custom package overlays — add local derivations or override upstream packages.
# Each attribute is available as pkgs.<name> throughout the entire flake.
final: _prev: {
  wine-ge-custom = final.callPackage ../pkgs/wine-ge-custom { };
}
