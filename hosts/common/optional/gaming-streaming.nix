{ pkgs, inputs, ... }:
{
  imports = [ inputs.apollo-flake.nixosModules."x86_64-linux".default ];

  environment.systemPackages = with pkgs; [
    obs-studio
    moonlight-qt
  ];

  services.apollo = {
    enable = true;
    capSysAdmin = true;
    openFirewall = true;
  };
}
