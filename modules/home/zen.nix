# modules/home/zen.nix — Zen browser via the zen-browser flake's HM module
# (a Firefox-style programs.zen-browser), themed by Stylix and translucent.
#
# The profile keeps Zen's own randomised directory name, which differs per
# machine, so it comes from the `zen.profilePath` hmArg (default "default" in
# sharedHmArgs in flake.nix). A host whose path doesn't exist yet gets a fresh
# profile; the old one stays on disk untouched.
{
  lib,
  config,
  inputs,
  zen,
  ...
}:
let
  gui = config.custom.hm.compositor != "none";
  profile = "default";
  palette = import ../../config/stylix/palette.nix;
  # Same 0.75 as kitty and fuzzel, as a CSS/Stylix alpha byte ("C0").
  alphaHex = lib.toHexString (builtins.ceil (0.75 * 255));
  # The window background is lower: Zen stacks it under other translucent
  # layers, and at 0.75 the result read as near-solid. 0.5 comes out about
  # as see-through as kitty at 0.75.
  bg = "${palette.bg0}${lib.toHexString (builtins.ceil (0.5 * 255))}";
in
{
  imports = [ inputs.zen-browser.homeModules.beta ];

  config = lib.mkIf gui {
    programs.zen-browser = {
      enable = true;
      profiles.${profile} = {
        id = 0;
        isDefault = true;
        name = "Default Profile";
        path = zen.profilePath;
        settings = {
          # Let the window background through so Hyprland's blur shows behind
          # the sidebar and toolbars (Zen's Linux counterpart to Windows Mica).
          # Page content stays opaque: browser.tabs.allow_transparent_browser
          # is left off, or pages without a background of their own go
          # see-through too.
          "zen.widget.linux.transparency" = true;
          # Without this Zen blends the sidebar onto an opaque base colour
          # even with the window transparent.
          "zen.theme.acrylic-elements" = true;
          # Firefox marks the whole toplevel as a Wayland opaque region, so
          # Hyprland neither blends nor blurs behind it and the translucent
          # CSS above renders as a solid colour. Drop the hint.
          "widget.wayland.opaque-region.enabled" = false;
          # On by default: an unfocused window swaps its background for the
          # solid system InactiveCaption colour, so the translucency vanished
          # whenever Zen lost focus.
          "zen.view.grey-out-inactive-windows" = false;
        };
        # Zen's theme script (ZenGradientGenerator) writes its workspace
        # gradient as inline custom properties on these two elements, which
        # beats Stylix's :root variables — so the sidebar kept Zen's own grey.
        # !important in a stylesheet outranks a non-important inline value.
        # The :root prefix outranks Stylix's own later, opaque
        # #zen-toolbar-background rule in the same file. The -old variants
        # are the crossfade source on workspace switches.
        userChrome = ''
          :root #zen-browser-background,
          :root #zen-toolbar-background {
            --zen-main-browser-background: ${bg} !important;
            --zen-main-browser-background-old: ${bg} !important;
            --zen-main-browser-background-toolbar: ${bg} !important;
            --zen-main-browser-background-toolbar-old: ${bg} !important;
          }
        '';
      };
    };

    stylix.targets.zen-browser = {
      profileNames = [ profile ];
      # Stylix derives this alpha from opacity.applications, which also feeds
      # zathura and others; set it here alone to match kitty/fuzzel's 0.75.
      opacityHex = lib.mkForce alphaHex;
    };
  };
}
