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

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };
}
