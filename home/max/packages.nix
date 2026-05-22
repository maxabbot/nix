{ pkgs, ... }:
{
  home.packages = with pkgs; [
    jq
    yq-go
    gh
    mkcert
    httpie
    rsync
    ffmpeg-full
    imagemagick
    nix-tree
    nix-diff
    nixpkgs-review
    nil
    claude-code
  ];
}
