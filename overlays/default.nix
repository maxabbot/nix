# Custom package overlays — add local derivations or override upstream packages.
# Each attribute is available as pkgs.<name> throughout the entire flake.
_final: prev: {
  # Local packages from pkgs/:
  # my-package = prev.callPackage ../pkgs/my-package { };

  # openldap's check phase runs a flaky syncrepl test (test017-syncreplication-refresh)
  # that times out / diverges in the build sandbox, breaking dependents like lutris.
  # Skip the test suite so the package (and its reverse-deps) build.
  openldap = prev.openldap.overrideAttrs (_old: { doCheck = false; });
}
