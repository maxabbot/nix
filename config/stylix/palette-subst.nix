# config/stylix/palette-subst.nix — template renderer for plain-text theme
# files. Returns a function `path -> string` that reads the file and replaces
# palette placeholders, one set per colour in palette.nix:
#
#   @name@       → "#d4be98"        (CSS / QML)
#   @name-hex@   → "d4be98"         (hyprland rgba(RRGGBBAA))
#   @name-rgb@   → "212, 190, 152"  (hyprlock rgba(r, g, b, a))
#
# Usage: renderTheme = import ./palette-subst.nix { inherit lib; };
#        xdg.configFile."foo".text = renderTheme ./foo.conf;
{ lib }:
let
  palette = import ./palette.nix;
  rgb =
    hex:
    lib.concatStringsSep ", " (
      map (off: toString (lib.fromHexString (builtins.substring off 2 (lib.removePrefix "#" hex)))) [
        0
        2
        4
      ]
    );
  tokens = lib.concatLists (
    lib.mapAttrsToList (name: value: [
      {
        placeholder = "@${name}@";
        inherit value;
      }
      {
        placeholder = "@${name}-hex@";
        value = lib.removePrefix "#" value;
      }
      {
        placeholder = "@${name}-rgb@";
        value = rgb value;
      }
    ]) palette
  );
in
path:
builtins.replaceStrings (map (t: t.placeholder) tokens) (map (t: t.value) tokens) (
  builtins.readFile path
)
