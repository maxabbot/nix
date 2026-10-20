# Custom package overlays — add local derivations or override upstream packages.
# Each attribute is available as pkgs.<name> throughout the entire flake.
final: prev: {
  wine-ge-custom = final.callPackage ../pkgs/wine-ge-custom { };

  # Papirus ships blue folders, which clash with Gruvbox. The package's own
  # `color` argument runs papirus-folders at build time; paleorange sits
  # closest to the palette's yellow. Overridden here rather than at the use
  # site so Stylix's icon theme and the system package stay the same build.
  papirus-icon-theme = prev.papirus-icon-theme.override { color = "paleorange"; };

  # 26.05 still ships 0.10.7; 1.0.0 adds frame-rate-independent smoothing and
  # better PipeWire error handling. Taken from unstable; drop once stable catches up.
  cava = final.unstable.cava;

  # 26.05 ships DMS 1.4.6; quickCapture and the current AvengeMedia plugins
  # need >= 1.6. Unstable's recipe, built against this set's Qt/KDE libraries
  # (same Qt as unstable today, but quickshell here is stable's, and QML
  # plugins have to match the Qt that loads them).
  #
  # 1.6 bakes its QML into the binary (`withshell`) and extracts it at run
  # time. Install the tree to share/quickshell/dms as well and point `dms` at
  # it — DMS's own flake does the same with -c. The env var rather than -c so
  # every subcommand, `dms ipc` included, resolves the same instance; and so
  # modules/home/wm/dms.nix can keep patching files under share/quickshell/dms.
  # The copy comes from the embed dir (`make sync-shell` output): DankCommon
  # symlink resolved, PAM paths substituted, dev files stripped.
  # Drop once nixpkgs stable carries >= 1.6.
  dms-shell =
    (final.unstable.dms-shell.override {
      inherit (final)
        buildGoModule
        kdePackages
        qt6
        fprintd
        pam
        pam_u2f
        coreutils
        installShellFiles
        makeWrapper
        ;
    }).overrideAttrs
      (old: {
        postInstall = old.postInstall + ''
          mkdir -p $out/share/quickshell/dms
          cp -r internal/shellembed/dist/. $out/share/quickshell/dms/
          wrapProgram $out/bin/dms --set DMS_SHELL_DIR $out/share/quickshell/dms
        '';
      });

  # Spotify started enforcing refresh-token expiry on 2026-07-20; from then on
  # 26.05's spotify-player 0.23.0 wipes its Web API token right after login (it
  # "refreshes" a PKCE token Spotify issued without a refresh_token), so every
  # request fails with "Token is not valid" / "no access token" and nothing
  # plays. Fixed in 0.24.1 (aome510/spotify-player#1040). 0.25.0 then fixes the
  # custom client_id path: Spotify strips fields (tracks, popularity, followers)
  # from Development-mode apps' responses, which 0.24 fails to parse (#1064);
  # 0.25 falls back to the shared ncspot ID for those requests. Unstable carries
  # 0.25.1, so take it from there. Drop once nixpkgs stable carries >= 0.25.1.
  spotify-player = final.unstable.spotify-player;
}
