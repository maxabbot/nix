{ pkgs, inputs, ... }:
{
  imports = [ inputs.apollo-flake.nixosModules.${pkgs.system}.default ];

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
