# Custom package overlays — add local derivations or override upstream packages.
# Each attribute is available as pkgs.<name> throughout the entire flake.
final: prev: {
  wine-ge-custom = final.callPackage ../pkgs/wine-ge-custom { };

  # Papirus ships blue folders, which clash with Gruvbox. The package's own
  # `color` argument runs papirus-folders at build time; paleorange sits
  # closest to the palette's yellow. Overridden here rather than at the use
  # site so Stylix's icon theme and the system package stay the same build.
  papirus-icon-theme = prev.papirus-icon-theme.override { color = "paleorange"; };

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

  # 26.05 ships Solaar 1.1.19, whose `solaar config` CLI dies on teardown under
  # PyGObject 3.56 — Gio.Application.run raises "Unable to marshal str as an
  # array". The setting does reach the device, but the crash pre-empts the save to
  # ~/.config/solaar/config.yaml, so every CLI change silently reverts the next
  # time the daemon restarts (and the CLI exits 1 even when it worked). 1.1.20
  # carries the one-line fix, "Wrap argv in list for Gio.Application.run"; that
  # bump landed on master just after the 26.05 branch cut and was never
  # backported, so no flake update will reach it. Drop once nixpkgs catches up.
  #
  # logitech-udev-rules is `solaar.udev` resolved against the final package set,
  # so the rules follow this override instead of drifting to the old version.
  # pkgs.unstable is added by a later overlay in flake.nix, hence `final`.
  solaar = final.unstable.solaar;

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
