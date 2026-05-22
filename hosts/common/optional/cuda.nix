{ pkgs, ... }:
{
  environment.systemPackages = with pkgs.cudaPackages; [
    cuda_nvcc
    cudnn
    pkgs.clinfo
  ];
}
