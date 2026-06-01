# hosts/work-laptop/default.nix — Work laptop (Hyprland, TLP, no gaming/nvidia).
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../modules/nixos/base.nix
    ../common/optional/development.nix
    ../common/optional/podman.nix
    ../common/optional/db-gui.nix
    ../common/optional/cloud-tools.nix
    ../common/optional/stylix.nix
    ../common/optional/productivity.nix
    ../common/optional/google-chrome.nix
    ../common/optional/comms.nix
  ];

  # ── Base ─────────────────────────────────────────────────────────────────────
  custom.base = {
    enable = true;
    username = "max";
    timezone = "Europe/London";
    hashedPassword = "$y$j9T$2U13TXbQqrmp.PD068E0E.$1uJPVe1dF1C0KhlXbn.iMg2qthRxOdp.9s/h6GG6YC6";
    sshKeys = [ ]; # add your public key: "ssh-ed25519 AAAA..."
    powerManagement = "tlp";
    firewall = true;
  };

  # ── TLP battery management ────────────────────────────────────────────────────
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      WIFI_PWR_ON_BAT = 5;
      NMI_WATCHDOG = 0;
    };
  };

  # ── Specialisations ───────────────────────────────────────────────────────────
  # Boot menu shows "powersave" entry for aggressive battery conservation.
  specialisation.powersave.configuration = {
    system.nixos.tags = [ "powersave" ];
    services.tlp.settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "power";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
    };
  };

  # ── Bootloader ────────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Networking ───────────────────────────────────────────────────────────────
  networking.hostName = "work-laptop";

  system.stateVersion = "24.11";
}
