# Custom package overlays — add local derivations or override upstream packages.
# Each attribute is available as pkgs.<name> throughout the entire flake.
final: prev: {
  wine-ge-custom = final.callPackage ../pkgs/wine-ge-custom { };

  # Papirus ships blue folders, which clash with Gruvbox. The package's own
  # `color` argument runs papirus-folders at build time; paleorange sits
  # closest to the palette's yellow. Overridden here rather than at the use
  # site so Stylix's icon theme and the system package stay the same build.
  papirus-icon-theme = prev.papirus-icon-theme.override { color = "paleorange"; };

  # nixpkgs still ships 0.10.7; 1.0.0 adds frame-rate-independent smoothing and
  # better PipeWire error handling. Drop this override once nixpkgs catches up.
  cava = prev.cava.overrideAttrs (_old: rec {
    version = "1.0.0";
    src = final.fetchFromGitHub {
      owner = "karlstav";
      repo = "cava";
      rev = version;
      hash = "sha256-0vQWobnt9pAZTJc45Lgcfad72BE8DUPGQ5/YwMSmU98=";
    };
  });

  # 26.05 ships Solaar 1.1.19, whose `solaar config` CLI dies on teardown under
  # PyGObject 3.56 — Gio.Application.run raises "Unable to marshal str as an
  # array". The setting does reach the device, but the crash pre-empts the save to
  # ~/.config/solaar/config.yaml, so every CLI change silently reverts the next
  # time the daemon restarts (and the CLI exits 1 even when it worked). 1.1.20
  # carries the one-line fix, "Wrap argv in list for Gio.Application.run"; that
  # bump landed on master just after the 26.05 branch cut and was never
  # backported, so no flake update will reach it. Drop once nixpkgs catches up.
  #
  # logitech-udev-rules is `solaar.udev` resolved against the final package set,
  # so the rules follow this override instead of drifting to the old version.
  # pkgs.unstable is added by a later overlay in flake.nix, hence `final`.
  solaar = final.unstable.solaar;

  # 26.05 ships DMS 1.4.6; quickCapture and the current AvengeMedia plugins
  # need >= 1.6. Unstable's recipe, built against this set's Qt/KDE libraries
  # (same Qt as unstable today, but quickshell here is stable's, and QML
  # plugins have to match the Qt that loads them).
  #
  # 1.6 bakes its QML into the binary (`withshell`) and extracts it at run
  # time. Install the tree to share/quickshell/dms as well and point `dms` at
  # it — DMS's own flake does the same with -c. The env var rather than -c so
  # every subcommand, `dms ipc` included, resolves the same instance; and so
  # shell-switcher.nix can keep patching files under share/quickshell/dms.
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
  # 0.25 falls back to the shared ncspot ID for those requests. Unstable only has
  # 0.24.1, so bump on top of it. Drop once nixpkgs stable carries >= 0.25.1.
  spotify-player = final.unstable.spotify-player.overrideAttrs (_old: rec {
    version = "0.25.1";
    src = final.fetchFromGitHub {
      owner = "aome510";
      repo = "spotify-player";
      rev = "v${version}";
      hash = "sha256-lJOHhrJ6ser1vs2m0pUnDpbnSgTtdTX/yXhCjvzCrTM=";
    };
    cargoDeps = final.rustPlatform.fetchCargoVendor {
      inherit src;
      name = "spotify-player-${version}";
      hash = "sha256-RsUuPkX4oVG6mDM16mM7VGW22mvKZPjShqs8BO36hbY=";
    };
  });

  # Upstream code-industry.net only hosts the newest tarball, so nixpkgs' pinned
  # 5.9.98 now 404s. Bump to whatever they currently publish; drop once nixpkgs
  # catches up. x86_64 only — every host here is.
  masterpdfeditor = prev.masterpdfeditor.overrideAttrs (_old: rec {
    version = "5.9.99";
    src = final.fetchurl {
      url = "https://code-industry.net/public/master-pdf-editor-${version}-qt5.x86_64-qt_include.tar.gz";
      hash = "sha256-ksVuJyuImstESVwHUmOUv6aERosg6g5bSsRvPSf5EVM=";
    };
  });
}
