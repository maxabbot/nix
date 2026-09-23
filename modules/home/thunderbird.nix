# modules/home/thunderbird.nix — Thunderbird, Gruvbox Material via userChrome.
#
# Stylix has no Thunderbird target, so this overrides the design tokens
# Thunderbird's own stylesheets derive everything from (layout.css's
# --layout-background/color/border scale, plus the spaces toolbar and
# selection colours) with palette values. Only chrome is restyled — no
# userContent, so emails render as their senders wrote them.
#
# HM names the profile directory after the profile, so an existing
# randomised one comes from the `thunderbird.profileName` hmArg (default
# "default" in sharedHmArgs in flake.nix).
{
  lib,
  config,
  thunderbird,
  ...
}:
let
  gui = config.custom.hm.compositor != "none";
  palette = import ../../config/stylix/palette.nix;
in
{
  config = lib.mkIf gui {
    programs.thunderbird = {
      enable = true;
      profiles.${thunderbird.profileName} = {
        isDefault = true;
        settings."toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        userChrome = with palette; ''
          :root, :host {
            --layout-background-0: ${bg0} !important;
            --layout-background-1: ${bgAlt} !important;
            --layout-background-2: ${bg1} !important;
            --layout-background-3: ${bg2} !important;
            --layout-background-4: ${bg3} !important;
            --layout-color-0: ${fgBrighter} !important;
            --layout-color-1: ${fg} !important;
            --layout-color-2: ${grayBright} !important;
            --layout-color-3: ${gray} !important;
            --layout-border-0: ${bg1} !important;
            --layout-border-1: ${bg2} !important;
            --layout-border-2: ${bg3} !important;
            --sidebar-highlight-background-color: ${blue} !important;
            --sidebar-highlight-text-color: ${bg0} !important;
            --selected-item-color: ${blue} !important;
            --selected-item-text-color: ${bg0} !important;
            --color-primary-default: ${blue} !important;
            --tree-view-bg: ${bg0} !important;
            --tree-view-color: ${fg} !important;
            --listbox-selected-bg: ${bg2} !important;
            --unread-color: ${fgBrighter} !important;
            --spaces-bg-color: ${bg0Hard} !important;
            --spaces-button-active-bg-color: ${blue} !important;
            --lwt-accent-color: ${bg0Hard} !important;
            --tabs-toolbar-background-color: ${bg0Hard} !important;
          }
        '';
      };
    };
  };
}
