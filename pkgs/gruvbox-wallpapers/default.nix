# pkgs/gruvbox-wallpapers — the rainbow logo wallpapers, rendered from
# config/stylix/palette.nix so they follow the palette like everything else.
#
#   rainbow-nix.png        Nix snowflake (config/plymouth/nix-snowflake.svg, the
#                          boot splash's logo). Limine menu and the DMS lock.
#   rainbow-framework.png  Framework gear in six wedges, same colour order
#                          (config/lock/). framework's DMS lock.
#
# Both 3480x2160 on bg0 with the logo centred at ~44% of the height, so either
# can stand in for the other and crop-fill trims the same on every output.
{
  lib,
  runCommand,
  writeText,
  librsvg,
  imagemagick,
}:
let
  renderTheme = import ../../config/stylix/palette-subst.nix { inherit lib; };
  palette = import ../../config/stylix/palette.nix;
  snowflake = writeText "nix-snowflake.svg" (renderTheme ../../config/plymouth/nix-snowflake.svg);
  gear = writeText "gruvbox-rainbow-framework.svg" (
    renderTheme ../../config/lock/gruvbox-rainbow-framework.svg
  );
in
runCommand "gruvbox-wallpapers"
  {
    nativeBuildInputs = [
      librsvg
      imagemagick
    ];
  }
  ''
    mkdir -p $out
    # The snowflake's lambdas span the full width of its square viewBox and
    # ~88% of its height, so 1092px puts the logo ~957px tall — the gear's size.
    rsvg-convert -w 1092 -h 1092 ${snowflake} -o snowflake.png
    magick -size 3480x2160 'xc:${palette.bg0}' snowflake.png -gravity center -composite \
      $out/rainbow-nix.png
    rsvg-convert ${gear} -o $out/rainbow-framework.png
  ''
