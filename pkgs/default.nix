# Locally-packaged derivations not (yet) in nixpkgs.
# Reference them in overlays/default.nix or directly:
#   pkgs.callPackage ./pkgs/my-package { }
{ }:
{
  # example = pkgs.callPackage ./example { };
}
