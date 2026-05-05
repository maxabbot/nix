# Custom package overlays — add local derivations or override upstream packages.
# Each attribute is available as pkgs.<name> throughout the entire flake.
final: prev: {
  # Local packages from pkgs/:
  # my-package = prev.callPackage ../pkgs/my-package { };

  # Example: override/patch an upstream package:
  # helix = prev.helix.overrideAttrs (_old: { doCheck = false; });
}
