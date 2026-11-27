# modules/home/firefox.nix — Firefox, the default browser (links, Super+B,
# $BROWSER — set in theme.nix and wm/hyprland.nix). Zen (zen.nix) is still
# installed alongside it.
#
# Native vertical tabs that expand on hover below Firefox's stock, always-shown
# nav bar, and Gruvbox Material chrome from the
# palette. Stylix's target supplies fonts and reader mode only; the colours
# live in userChrome (as thunderbird.nix does). The chrome is opaque, unlike
# Zen/kitty: Firefox forces the hover-expanded sidebar opaque because it
# animates over the page, and a translucent window made that animation leave
# stale frames. Blank and new-tab pages get the palette's background.
#
# HM names the profile directory after the profile, so unlike Zen there's no
# per-host path. Extensions come from the firefox-addons flake; their own
# state (Bitwarden login, Dark Reader site list) stays in the profile.
{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  gui = config.custom.hm.compositor != "none";
  profile = "default";
  palette = import ../../config/stylix/palette.nix;
  addons = inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  config = lib.mkIf gui {
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

          # ── Startup ────────────────────────────────────────────────────
          # Reopen the last session's windows and tabs.
          "browser.startup.page" = 3;

          # ── Security ───────────────────────────────────────────────────
          # Upgrade every load to HTTPS; a plain-HTTP-only site gets a
          # one-click interstitial instead of silently loading.
          "dom.security.https_only_mode" = true;

          # ── Telemetry and studies ──────────────────────────────────────
          "datareporting.healthreport.uploadEnabled" = false;
          "datareporting.policy.dataSubmissionEnabled" = false;
          "datareporting.usage.uploadEnabled" = false;
          "toolkit.telemetry.unified" = false;
          "toolkit.telemetry.archive.enabled" = false;
          "toolkit.telemetry.bhrPing.enabled" = false;
          "toolkit.telemetry.newProfilePing.enabled" = false;
          "toolkit.telemetry.firstShutdownPing.enabled" = false;
          "toolkit.telemetry.shutdownPingSender.enabled" = false;
          "app.shield.optoutstudies.enabled" = false;
          "app.normandy.enabled" = false;
          # Extension/feature recommendations in about:addons.
          "browser.discovery.enabled" = false;

          # ── AI features ────────────────────────────────────────────────
          # browser.ml.enable gates the local ML engine (smart tab groups,
          # link previews, PDF alt-text); translations use their own engine
          # and keep working.
          "browser.ml.enable" = false;
          "browser.ml.chat.enabled" = false;
          "browser.ml.chat.sidebar" = false;
          "browser.ml.chat.shortcuts" = false;
          "browser.ml.chat.page" = false;
          "browser.ml.linkPreview.enabled" = false;
          "browser.tabs.groups.smart.enabled" = false;
          "browser.smartwindow.enabled" = false;
          "extensions.ml.enabled" = false;

          # ── Layout: out of the way ─────────────────────────────────────
          "sidebar.revamp" = true;
          "sidebar.verticalTabs" = true;
          # Collapsed to icons; expands over the page on hover.
          "sidebar.visibility" = "expand-on-hover";
          # The hover slide defaults to 400ms, double the 200ms click toggle;
          # stretched that long, any dropped frame reads as judder.
          "sidebar.animation.expand-on-hover.duration-ms" = 200;
          # No client-side titlebar or window buttons (Hyprland tiles it).
          "browser.tabs.inTitlebar" = 0;
          "browser.toolbars.bookmarks.visibility" = "never";
          "browser.newtabpage.activity-stream.showSponsored" = false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          # New tab is search + your shortcuts only: no story feed, weather
          # or widgets. URL bar: no sponsored or trending suggestions.
          "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
          "browser.newtabpage.activity-stream.showWeather" = false;
          "browser.newtabpage.activity-stream.widgets.enabled" = false;
          "browser.urlbar.suggest.quicksuggest.sponsored" = false;
          "browser.urlbar.suggest.trending" = false;
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
          # Page background in dark mode where a page sets none: about:blank,
          # the flash before a page paints, and unstyled pages.
          "browser.display.background_color.dark" = palette.bg0;
          "browser.display.foreground_color.dark" = palette.fg;
          "ui.systemUsesDarkTheme" = 1;
        };

        # Firefox 159's "Nova" design-token names (the older --toolbar-bgcolor
        # / --lwt-* names are gone). The toolbox colour paints both the top
        # strip and the vertical-tab sidebar.
        userChrome = with palette; ''
          /* ── Gruvbox Material chrome ─────────────────────────────────── */
          :root {
            --toolbox-background-color: ${bg0} !important;
            --toolbox-text-color: ${fg} !important;
            --toolbar-background-color: ${bg0} !important;
            --toolbar-text-color: ${fg} !important;
            --toolbar-field-background-color: ${bgAlt} !important;
            --toolbar-field-text-color: ${fg} !important;
            --toolbar-field-background-color-focus: ${bg1} !important;
            --toolbar-field-border-color-focus: ${blue} !important;
            --sidebar-background-color: ${bg0} !important;
            --sidebar-text-color: ${fg} !important;
            --tab-background-color-selected: ${bg2} !important;
            --tab-text-color-selected: ${fgBrighter} !important;
            --panel-background-color: ${bg0} !important;
            --panel-text-color: ${fg} !important;
            --panel-border-color: ${bg2} !important;
            --focus-outline-color: ${blue} !important;
          }
        '';

        # New tab / home / private-browsing pages: Firefox's own canvas
        # colours swapped for the palette (activity-stream.css's tokens).
        userContent = with palette; ''
          @-moz-document url("about:newtab"), url("about:home"),
            url("about:privatebrowsing") {
            :root {
              --newtab-background-color: ${bg0} !important;
              --newtab-background-color-secondary: ${bg1} !important;
              --newtab-text-primary-color: ${fg} !important;
              --newtab-primary-action-background: ${blue} !important;
            }
          }
        '';
      };
    };

    stylix.targets.firefox.profileNames = [ profile ];
  };
}
