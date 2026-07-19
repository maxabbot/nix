{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # One coherent interpreter with its libraries on PYTHONPATH — individual
    # python3Packages.* entries in systemPackages are separate store paths the
    # interpreter can't import from. Project work should still prefer uv/direnv.
    (python3.withPackages (
      ps: with ps; [
        pip
        virtualenv
        matplotlib
        numpy
        pandas
        scipy
        scikit-learn
      ]
    ))
    go
    rustup
    jdk
    gcc
    clang
    cmake
    gnumake
    shellcheck
    cloc # count lines of code by language
    tig
    sqlite
    yq-go # mikefarah yq — the python `yq` wrapper would be a second, conflicting bin/yq
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
  # unaffected, as is nixos-anywhere (which talks to the live-ISO sshd at install time).
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
