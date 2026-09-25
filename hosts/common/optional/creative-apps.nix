{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    gimp
    inkscape
    krita
    # LMMS 1.3, packaged from the upstream AppImage (see flake.nix) rather than
    # nixpkgs' outdated 1.2.2 — full native LV2 support (Carla rack, Surge XT)
    # instead of 1.2.x's clunky embed-only workaround. Pre-release: project
    # files saved with it can't be reopened in LMMS 1.2.x, so don't round-trip.
    lmms-appimage
    surge-xt
  ];
}
