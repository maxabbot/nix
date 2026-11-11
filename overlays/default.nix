# Custom package overlays — add local derivations or override upstream packages.
# Each attribute is available as pkgs.<name> throughout the entire flake.
final: prev: {
  # Rainbow Nix / Framework logo wallpapers rendered from the palette (Limine,
  # the DMS lock).
  gruvbox-wallpapers = final.callPackage ../pkgs/gruvbox-wallpapers { };

  # Swap Claude Code between saved logins; also driven by the claudeUsage
  # widget's popout (modules/home/wm/dms-plugins.nix).
  claude-account = final.callPackage ../pkgs/claude-account { };

  # Papirus ships blue folders, which clash with Gruvbox. The package's own
  # `color` argument runs papirus-folders at build time; paleorange sits
  # closest to the palette's yellow. Overridden here rather than at the use
  # site so Stylix's icon theme and the system package stay the same build.
  papirus-icon-theme = prev.papirus-icon-theme.override { color = "paleorange"; };

  # 26.05 still ships 0.10.7; 1.0.0 adds frame-rate-independent smoothing and
  # better PipeWire error handling. Taken from unstable; drop once stable catches up.
  cava = final.unstable.cava;

  # Clight (hosts/common/optional/clight.nix) should drive the internal panel
  # only; with DDC, clightd also takes over external monitors and fights the
  # DMS brightness slider, which already drives them over DDC/CI.
  clightd = prev.clightd.override { enableDdc = false; };

  # vitetris aborts ("buffer overflow detected") the moment a game starts:
  # options.c uses the struct hack — strcpy into `char tp_key[4]` at the end
  # of a struct malloc'd large enough for the whole key — and fortify only
  # sees the declared 4 bytes. A false positive at any fortify level, so
  # fortify is off for this package alone.
  vitetris = prev.vitetris.overrideAttrs (old: {
    hardeningDisable = (old.hardeningDisable or [ ]) ++ [ "fortify" ];
  });

  # VSCode 1.144 moved its bundled ripgrep to the asar's unpacked tree
  # (@vscode/ripgrep-universal/bin/linux-x64/rg), but nixpkgs' postPatch still
  # removes the old @vscode/ripgrep/bin/rg path before linking Nix's ripgrep,
  # so the build fails. Retarget that swap at the new path; drop once nixpkgs'
  # recipe handles 1.144 (the replaceStrings then matches nothing, harmlessly).
  vscode = prev.vscode.overrideAttrs (old: {
    postPatch =
      builtins.replaceStrings
        [ "resources/app/node_modules/@vscode/ripgrep/bin/rg" ]
        [ "resources/app/node_modules.asar.unpacked/@vscode/ripgrep-universal/bin/linux-x64/rg" ]
        old.postPatch;
  });

  # 26.05 ships DMS 1.4.6; the current plugin registry needs 2.0, which
  # nixpkgs carries as dux-shell (DMS's new name; the binary is still `dms`).
  # Kept under the dms-shell attribute so every consumer here (the shell in
  # modules/home/wm/dms.nix, the flake check) gets this build; the greeter
  # is a separate binary since 2.1 (productivity.nix). Unstable's recipe,
  # built against this set's Qt/KDE libraries (quickshell here is stable's,
  # and QML plugins have to match the Qt that loads them). The Go toolchain stays unstable's: 2.0
  # needs Go 1.27, and the Go side doesn't link Qt.
  #
  # DMS bakes its QML into the binary (`withshell`) and extracts it at run
  # time. Install the tree to share/quickshell/dms as well and point `dms` at
  # it — DMS's own flake does the same with -c. The env var rather than -c so
  # every subcommand, `dms ipc` included, resolves the same instance; and so
  # modules/home/wm/dms.nix can keep patching files under share/quickshell/dms.
  # The copy comes from the embed dir (`make sync-shell` output): DCommon
  # symlink resolved, PAM paths substituted, dev files stripped.
  # Drop once nixpkgs stable carries dux-shell >= 2.0.
  dms-shell =
    (final.unstable.dux-shell.override {
      inherit (final)
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

  # Hyprland segfaults when a touch lands on a window or layer that has no
  # surface: onTouchDown passes the empty pointer to sendTouchDown, which calls
  # surf->client() unchecked. Hit on framework (2026-11-09) by a touchscreen
  # touch during resume, while the session was locked and the dock's outputs
  # were going away. Still unguarded on upstream main as of v0.57.1. Drop
  # once Hyprland checks the surface itself.
  hyprland = prev.hyprland.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./hyprland-touch-null-surface.patch ];
  });
}
