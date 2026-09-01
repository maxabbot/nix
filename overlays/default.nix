# Custom package overlays — add local derivations or override upstream packages.
# Each attribute is available as pkgs.<name> throughout the entire flake.
final: prev: {
  wine-ge-custom = final.callPackage ../pkgs/wine-ge-custom { };

  # nixpkgs still ships 0.10.7; 1.0.0 adds frame-rate-independent smoothing and
  # better PipeWire error handling. Drop this override once nixpkgs catches up.
  cava = prev.cava.overrideAttrs (_old: rec {
    version = "1.0.0";
    src = final.fetchFromGitHub {
      owner = "karlstav";
      repo = "cava";
      rev = version;
      hash = "sha256-0vQWobnt9pAZTJc45Lgcfad72BE8DUPGQ5/YwMSmU98=";
    };
  });

  # Upstream code-industry.net only hosts the newest tarball, so nixpkgs' pinned
  # 5.9.98 now 404s. Bump to whatever they currently publish; drop once nixpkgs
  # catches up. x86_64 only — every host here is.
  masterpdfeditor = prev.masterpdfeditor.overrideAttrs (_old: rec {
    version = "5.9.99";
    src = final.fetchurl {
      url = "https://code-industry.net/public/master-pdf-editor-${version}-qt5.x86_64-qt_include.tar.gz";
      hash = "sha256-ksVuJyuImstESVwHUmOUv6aERosg6g5bSsRvPSf5EVM=";
    };
  });
}
