# Custom package overlays — add local derivations or override upstream packages.
# Each attribute is available as pkgs.<name> throughout the entire flake.
_final: _prev: {
  # Local packages from pkgs/:
  # my-package = prev.callPackage ../pkgs/my-package { };

  # Example: override/patch an upstream package:
  # my-package = prev.my-package.overrideAttrs (_old: { doCheck = false; });
}
