{ pkgs, inputs, ... }:
let
  wineGe = pkgs.wine-ge-custom;
in
{
  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.nix-index-database.comma.enable = true;

  # Expose Wine-GE as a Lutris runner — Lutris scans ~/.local/share/lutris/runners/wine/
  xdg.dataFile."lutris/runners/wine/${wineGe.version}".source = wineGe;

  home.packages = with pkgs; [
    yq-go
    gh
    mkcert
    httpie
    pandoc # renders SHORTCUTS.md → HTML for the cheat-sheet wallpaper
    ffmpeg-full
    imagemagick
    nix-tree
    nix-diff
    nixpkgs-review
    nil
    inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    v4l-utils
    cheese
    spotify
    stremio-linux-shell
    qbittorrent
  ];
}
