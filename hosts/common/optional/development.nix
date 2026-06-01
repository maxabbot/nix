{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    python3
    python3Packages.pip
    python3Packages.virtualenv
    go
    rustup
    jdk
    gcc
    clang
    cmake
    gnumake
    python3Packages.matplotlib
    python3Packages.numpy
    python3Packages.pandas
    python3Packages.scipy
    python3Packages.scikit-learn
    shellcheck
    tig
    sqlite
    yq
    uv
    quickemu
    quickgui
    bun
    curlie
    bruno
    pgcli
  ];

  programs.direnv.enable = true;

  # SSH server disabled — no incoming SSH on these hosts. Outbound git/ssh is
  # unaffected, as is deploy.sh (which talks to the live-ISO sshd at install time).
  # To allow remote login later: set enable = true and populate custom.base.sshKeys
  # (the settings below keep it key-only so re-enabling is safe by default).
  services.openssh = {
    enable = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
