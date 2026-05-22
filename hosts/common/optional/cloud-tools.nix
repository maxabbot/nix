{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    kubectl
    kubectx
    kubernetes-helm
    opentofu
    awscli2
    azure-cli
    google-cloud-sdk
    doctl
  ];
}
