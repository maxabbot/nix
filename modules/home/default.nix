# modules/home/default.nix — Root Home Manager module; imports all sub-modules.
{ ... }:
{
  imports = [
    ./shell.nix
    ./editor.nix
    ./apps.nix
    ./theme.nix
    ./wm/hyprland.nix
    ./wm/waybar.nix
  ];
}
