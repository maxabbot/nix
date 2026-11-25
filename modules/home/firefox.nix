# modules/home/firefox.nix — Firefox, trialled alongside Zen (hosts opt in
# with the `firefox.enable` hmArg; Zen stays the default browser until this
# replaces it).
#
# Native vertical tabs that expand on hover, a nav bar that stays collapsed
# until hovered or focused (Ctrl+L), and Gruvbox Material chrome from the
# palette, translucent like Zen/kitty so Hyprland's blur shows through.
# Stylix's target supplies fonts and reader mode only: its colour theme is
# the Firefox Color extension, whose opaque colours would cover the
# translucency, so the colours live in userChrome instead (as thunderbird.nix
# does). Page content stays opaque (browser.tabs.allow_transparent_browser
# is left off).
#
# HM names the profile directory after the profile, so unlike Zen there's no
# per-host path. Extensions come from the firefox-addons flake; their own
# state (Bitwarden login, Dark Reader site list) stays in the profile.
{
  lib,
  config,
  pkgs,
  inputs,
  firefox,
  ...
}:
let
  gui = config.custom.hm.compositor != "none";
  profile = "default";
  palette = import ../../config/stylix/palette.nix;
  addons = inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
  # Same 0.75 as kitty and Zen's toolbars, as a CSS alpha byte ("C0").
  alpha = lib.toHexString (builtins.ceil (0.75 * 255));
  translucent = colour: "${colour}${alpha}";
in
{
  config = lib.mkIf (gui && firefox.enable) {
    programs.firefox = {
      enable = true;
      # The XDG path (HM's default from stateVersion 26.05 on); set
      # explicitly so the 24.11 stateVersion doesn't fall back to ~/.mozilla.
      configPath = "${config.xdg.configHome}/mozilla/firefox";
      # Installed by policy from releases.mozilla.org at the packaged
      # version, so it tracks nixpkgs' Firefox and never mismatches.
      languagePacks = [ "en-GB" ];

      profiles.${profile} = {
        id = 0;
        isDefault = true;

        extensions.packages = with addons; [
          ublock-origin
          bitwarden
          darkreader
          react-devtools
          # Spellcheck only: Mozilla ships no en-NZ interface (en-GB is the
          # closest), but there is an NZ dictionary.
          new-zealand-english-dict
        ];

        settings = {
          # ── Declarative extensions ─────────────────────────────────────
          # Profile-installed extensions are "sideloaded", which Firefox
          # disables until approved one by one. Trust the Nix-installed ones.
          "extensions.autoDisableScopes" = 0;

          # ── Locale ─────────────────────────────────────────────────────
          # No en-NZ UI locale exists; en-GB is the closest. Sites get en-NZ
          # first, and dates/numbers follow the system's en_NZ.
          "intl.locale.requested" = "en-GB";
          "spellchecker.dictionary" = "en-NZ";
          "intl.accept_languages" = "en-NZ, en-GB, en";
          "intl.regional_prefs.use_os_locales" = true;

          # ── Layout: out of the way ─────────────────────────────────────
          "sidebar.revamp" = true;
          "sidebar.verticalTabs" = true;
          # Collapsed to icons; expands over the page on hover.
          "sidebar.visibility" = "expand-on-hover";
          # No client-side titlebar or window buttons (Hyprland tiles it).
          "browser.tabs.inTitlebar" = 0;
          "browser.toolbars.bookmarks.visibility" = "never";
          "browser.newtabpage.activity-stream.showSponsored" = false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          "browser.aboutConfig.showWarning" = false;
          # Toolbar layout, reapplied from user.js on every start, so it lives
          # here and in-browser rearranging reverts on restart. Firefox's own
          # vertical-tabs migration put forward before back, right of the URL
          # bar. Extension widget IDs are the add-on ID mangled to
          # [a-z0-9_]: ones in "seen" but not placed stay in the extensions
          # menu; a new extension auto-places once, then reverts until listed
          # here. downloads-button only shows while there's a download.
          "browser.uiCustomization.state" = builtins.toJSON {
            placements = {
              nav-bar = [
                "back-button"
                "forward-button"
                "stop-reload-button"
                "vertical-spacer"
                "urlbar-container"
                "downloads-button"
                "ublock0_raymondhill_net-browser-action"
                "unified-extensions-button"
              ];
              unified-extensions-area = [
                "_react-devtools-browser-action"
                "addon_darkreader_org-browser-action"
                "_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action" # Bitwarden
              ];
              vertical-tabs = [ "tabbrowser-tabs" ];
              TabsToolbar = [ ];
              PersonalToolbar = [ "personal-bookmarks" ];
              toolbar-menubar = [ "menubar-items" ];
              widget-overflow-fixed-list = [ ];
            };
            # Widgets Firefox has already auto-placed once; listing them stops
            # it re-adding the dropped ones (AI window, smart-window groups).
            seen = [
              "ublock0_raymondhill_net-browser-action"
              "_react-devtools-browser-action"
              "addon_darkreader_org-browser-action"
              "_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action"
              "reset-pbm-toolbar-button"
              "smartwindow-group-tabs-button"
              "ai-window-toggle"
              "developer-button"
              "screenshot-button"
            ];
            dirtyAreaCache = [
              "nav-bar"
              "unified-extensions-area"
              "vertical-tabs"
              "TabsToolbar"
              "PersonalToolbar"
              "toolbar-menubar"
            ];
            currentVersion = 28;
            newElementCount = 0;
          };

          # ── Theme ──────────────────────────────────────────────────────
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          "ui.systemUsesDarkTheme" = 1;
          # Translucent chrome: an RGBA toplevel, and (as for Zen) no
          # Wayland opaque-region hint, or Hyprland renders it solid.
          "widget.transparent-windows" = true;
          "widget.wayland.opaque-region.enabled" = false;
        };

        # Firefox 159's "Nova" design-token names (the older --toolbar-bgcolor
        # / --lwt-* names are gone). The toolbox colour paints both the top
        # strip and the vertical-tab sidebar; toolbar and sidebar are cleared
        # so it's the only translucent layer, not stacked ones.
        userChrome = with palette; ''
          /* ── Gruvbox Material chrome ─────────────────────────────────── */
          :root {
            --toolbox-background-color: ${translucent bg0} !important;
            --toolbox-text-color: ${fg} !important;
            --toolbar-background-color: transparent !important;
            --toolbar-text-color: ${fg} !important;
            --toolbar-field-background-color: ${bgAlt} !important;
            --toolbar-field-text-color: ${fg} !important;
            --toolbar-field-background-color-focus: ${bg1} !important;
            --toolbar-field-border-color-focus: ${blue} !important;
            --sidebar-background-color: transparent !important;
            --sidebar-text-color: ${fg} !important;
            --tab-background-color-selected: ${bg2} !important;
            --tab-text-color-selected: ${fgBrighter} !important;
            --panel-background-color: ${bg0} !important;
            --panel-text-color: ${fg} !important;
            --panel-border-color: ${bg2} !important;
            --focus-outline-color: ${blue} !important;
          }

          /* The two opaque layers under the chrome: the window itself, and
             the sidebar's container (found by elimination; clearing every
             other #browser child changed nothing). */
          #main-window,
          #sidebar-container {
            background-color: transparent !important;
          }

          /* ── Auto-hiding nav bar ─────────────────────────────────────── */
          /* Collapsed to a thin strip at the top; hover, keyboard focus
             (Ctrl+L, F6) or an open panel (extension popup, menu) brings it
             back. It pushes the page down rather than overlaying it. */
          #navigator-toolbox {
            padding-bottom: 4px !important;
            border-bottom: none !important;
          }
          #nav-bar {
            max-height: 0 !important;
            min-height: 0 !important;
            overflow: clip !important;
            opacity: 0;
            transition:
              max-height 150ms ease,
              opacity 150ms ease !important;
          }
          #navigator-toolbox:hover #nav-bar,
          #navigator-toolbox:focus-within #nav-bar,
          #nav-bar:has([open]) {
            max-height: 48px !important;
            overflow: visible !important;
            opacity: 1;
          }
        '';
      };
    };

    stylix.targets.firefox.profileNames = [ profile ];
  };
}
