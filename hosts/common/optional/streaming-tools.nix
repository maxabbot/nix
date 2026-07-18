{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    obs-studio
    shotcut
    rustdesk
    losslesscut-bin
  ];

  # Installs the package and setcap-wraps gsr-kms-server — without the
  # wrapper, KMS capture stops for polkit root auth on every recording.
  programs.gpu-screen-recorder.enable = true;
}
