{
  pkgs,
  lib,
  config,
  osConfig,
  inputs,
  ...
}:
let
  gui = config.custom.hm.compositor != "none";
  # Lutris ships with gaming.nix, which also enables Steam — use that as the
  # "gaming host" signal so Wine-GE isn't built on the laptop/headless hosts.
  gaming = osConfig.programs.steam.enable;
  wineGe = pkgs.wine-ge-custom;
in
{
  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.nix-index-database.comma.enable = true;

  # Expose Wine-GE as a Lutris runner — Lutris scans ~/.local/share/lutris/runners/wine/
  xdg.dataFile."lutris/runners/wine/${wineGe.version}" = lib.mkIf gaming { source = wineGe; };

  home.packages =
    with pkgs;
    [
      yq-go
      gh
      mkcert
      httpie
      pandoc # renders SHORTCUTS.md → HTML for the cheat-sheet wallpaper
      ffmpeg-full
      sox # audio record/play CLI (`rec`/`play`) — Claude Code voice mode
      imagemagick
      nix-tree
      nix-diff
      nixpkgs-review
      nil
      inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.claude-code

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
      glow # render markdown in the terminal
      mdr # render markdown in the terminal (alt to glow)
    ]
    # GUI-only apps — skipped on the headless `minimal` host
    ++ lib.optionals gui [
      v4l-utils
      cheese
      spotify
      stremio-linux-shell
      qbittorrent
    ];
}
