{ pkgs, inputs, ... }:
{
  imports = [ inputs.apollo-flake.nixosModules."x86_64-linux".default ];

  # obs-studio comes from streaming-tools.nix (imported alongside this module).
  environment.systemPackages = with pkgs; [
    moonlight-qt
  ];

  services.apollo = {
    enable = true;
    package = inputs.apollo-flake.packages.x86_64-linux.default;
    capSysAdmin = true;
    openFirewall = true;
  };
}
