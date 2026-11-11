{
  pkgs,
  lib,
  config,
  osConfig,
  ...
}:
let
  gui = config.custom.hm.compositor != "none";
  # Lutris ships with gaming.nix, which also enables Steam — use that as the
  # "gaming host" signal so GE-Proton is only pulled in where Lutris is.
  gaming = osConfig.programs.steam.enable;
  protonGe = pkgs.proton-ge-bin;
in
{
  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.nix-index-database.comma.enable = true;

  # GE-Proton as a Lutris wine version — nixpkgs' proton-ge-bin, the build
  # Steam gets from gaming.nix. Lutris lists any directory under
  # ~/.local/share/lutris/runners/wine/ that holds a `proton` script and runs
  # it through umu (umu-launcher, gaming.nix). Replaces wine-ge-custom, whose
  # GE-Proton8-26 was the last Wine-GE release before it was discontinued.
  xdg.dataFile."lutris/runners/wine/${protonGe.version}" = lib.mkIf gaming {
    source = protonGe.steamcompattool;
  };

  # Steam's Linux client downloads slowly over HTTP/2 and under-opens connections;
  # these dev-cfg flags (read at startup, needs a full Steam restart) fix both.
  xdg.dataFile."Steam/steam_dev.cfg" = lib.mkIf gaming {
    text = ''
      @nClientDownloadEnableHTTP2PlatformLinux 0
      @fDownloadRateImprovementToAddAnotherConnection 1.0
    '';
  };

  home.packages =
    with pkgs;
    [
      # yq comes from development.nix (yq-go, system-wide)
      gh
      mkcert
      pandoc # renders SHORTCUTS.md → HTML for the cheat-sheet wallpaper
      ffmpeg-full
      imagemagick
      nix-tree
      nix-diff
      nixpkgs-review
      nil

      # ── Data wrangling (CSV/JSON/parquet reconciliation, statement parsing) ──────
      visidata # interactive TUI table explorer (CSV/JSON/xlsx/parquet)
      miller # awk/sed/cut for CSV/TSV/JSON, format-aware (mlr)
      dasel # jq across JSON/YAML/TOML/CSV/XML with one syntax
      qsv # fast CSV stats/slice/join for large files

      # ── Modern CLI (completes the eza/bat/delta/zoxide family) ───────────────────
      just # command/task runner (justfile)
      sd # sed replacement, intuitive find-and-replace
      dust # du replacement, tree-style disk usage
      duf # df replacement
      procs # ps replacement
      tealdeer # tldr client — simplified man-page examples
      watchexec # run commands on file change
      mdr # render markdown in the terminal
    ]
    # GUI-only apps — skipped when no compositor is configured
    ++ lib.optionals gui [
      v4l-utils
      cameractrls-gtk4 # live UVC webcam controls (GTK) — framework persists its picks via udev
      cheese
      spotify
      stremio-linux-shell
      qbittorrent
      # Games — the terminal ones live in terminal-toys.nix
      pinball # Emilia Pinball (SDL)
      cataclysm-dda # zombie roguelike, tiles build (`cataclysm-tiles`); the curses one isn't cached
      dwarf-fortress # DF 53 (the graphical Steam-era release)
      openttd # Transport Tycoon Deluxe remake (fetches OpenGFX/OpenSFX in-game)
      shattered-pixel-dungeon # roguelike
      widelands # Settlers II-style economy/strategy
      superTuxKart # kart racer
      # `autoclick` — hold g → 100 CPS left-click via theclicker (productivity.nix)
      (pkgs.writeShellScriptBin "autoclick" (builtins.readFile ../../config/scripts/autoclick))
    ];
}
