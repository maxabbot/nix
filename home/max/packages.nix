{ pkgs, ... }:
{
  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.nix-index-database.comma.enable = true;

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
    claude-code
    spotify
    stremio
  ];
}
