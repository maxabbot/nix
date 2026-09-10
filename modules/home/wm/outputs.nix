# modules/home/wm/outputs.nix — split the configured monitors into portrait and
# landscape connectors.
#
# Shared by waybar.nix and shell-switcher.nix so every bar agrees on which
# output gets the trimmed layout. Monitor strings look like
# "DP-2,3840x2160@60,1920x0,1.5,transform,1"; transform 1/3 = 90°/270° = portrait.
#
# Usage: outputs = import ./outputs.nix { inherit lib; } config.custom.hm;
{ lib }:
cfg:
let
  monitorStrings = lib.filter (m: m != null) [
    cfg.monitors.primary
    cfg.monitors.secondary
  ];

  isPortrait =
    s:
    let
      parts = lib.splitString "," s;
    in
    builtins.length parts >= 6
    && builtins.elemAt parts 4 == "transform"
    && lib.elem (builtins.elemAt parts 5) [
      "1"
      "3"
    ];

  connector = s: lib.head (lib.splitString "," s);
in
rec {
  portraitOutputs = map connector (lib.filter isPortrait monitorStrings);
  landscapeOutputs = map connector (lib.filter (s: !isPortrait s) monitorStrings);
  allOutputs = map connector monitorStrings;
  hasPortrait = portraitOutputs != [ ];
}
