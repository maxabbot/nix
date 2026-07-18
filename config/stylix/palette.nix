# config/stylix/palette.nix — Gruvbox Material Dark, the single source of truth
# for every colour in the repo. Plain attrset: `import`-able from both NixOS
# modules (stylix.nix derives the base16 scheme from it) and Home Manager
# modules (waybar, tmux, starship, kitty, cava, spotify-player interpolate it).
#
# Names follow classic Gruvbox structural slots (bg0..bg4, fg) plus the
# gruvbox-material accent names. The base16 slot each value fills is noted
# so the mapping in stylix.nix stays auditable.
#
# Not covered (hand-maintained copies — keep in sync when changing a colour):
#   config/hypr-scripts/quickshell/Theme.qml   (QML-side single source)
#   config/hypr/hyprlock.conf, config/hypr/shortcuts.css,
#   config/hypr/hyprland.lua, config/fastfetch/config.jsonc
{
  # ── Backgrounds (dark → light) ─────────────────────────────────────────────
  bg0Hard = "#1d2021"; #          hard background (waybar bar, active-pill text)
  bg0 = "#282828"; # base00       default background
  bgAlt = "#32302f"; #            soft background (inputs, tiles)
  bg1 = "#3c3836"; # base01       status bar / capsule background
  bg2 = "#504945"; # base02       selection background
  bg3 = "#665c54"; # base03       mid background
  bg4 = "#7c6f64"; #              lightest background / dimmest grey
  gray = "#928374"; # base04      comments / dim foreground
  grayBright = "#a89984"; #       brightest grey (muted text on soft bg)

  # ── Foregrounds (default → light) ──────────────────────────────────────────
  fg = "#d4be98"; # base05        default foreground
  fgBright = "#ddc7a1"; # base06  lighter foreground
  fgBrighter = "#e2cca9"; # base07 lightest foreground

  # ── Accents ────────────────────────────────────────────────────────────────
  red = "#ea6962"; # base08
  orange = "#e78a4e"; # base09
  yellow = "#d8a657"; # base0A
  green = "#a9b665"; # base0B
  aqua = "#89b482"; # base0C
  blue = "#7daea3"; # base0D
  purple = "#d3869b"; # base0E
  brown = "#bd6f3e"; # base0F
}
