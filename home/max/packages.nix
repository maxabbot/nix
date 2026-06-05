{ pkgs, inputs, ... }:
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
    inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    spotify
    stremio-linux-shell
  ];
}
