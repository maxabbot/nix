# hosts/work-laptop/default.nix — Work laptop: Lenovo ThinkBook 14 2-in-1 G4 IML
# (Core Ultra 7 155U, Meteor Lake, Intel iGPU, 16 GB RAM), booted off an external
# USB SSD. Hyprland, TLP, no gaming/nvidia. Full specs in hardware-configuration.nix.
{ lib, pkgs, ... }:
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
    ../common/optional/lan-mouse.nix
    ../common/optional/logitech.nix
    ../common/optional/limine.nix
  ];

  home-manager.backupFileExtension = "backup";

  # ── Base ─────────────────────────────────────────────────────────────────────
  custom.base = {
    enable = true;
    username = "max";
    hashedPassword = "$y$j9T$2U13TXbQqrmp.PD068E0E.$1uJPVe1dF1C0KhlXbn.iMg2qthRxOdp.9s/h6GG6YC6";
    sshKeys = [ ]; # add your public key: "ssh-ed25519 AAAA..."
    powerManagement = "tlp";
  };

  # ── Nix builds ───────────────────────────────────────────────────────────────
  # base.nix caps max-jobs at 1 for the RAM-constrained hosts. Now that this one
  # has a 16G swapfile (hardware-configuration.nix) there is room to parallelise,
  # but not to the "auto" that home-desktop uses: auto means one job per logical
  # core, and 14 concurrent jobs on a Core Ultra 7 155U with 15.3 GiB usable is
  # how the OOM kills happened in the first place. Two jobs is the useful part of
  # the win — it overlaps a stalled download or a single-threaded configure phase
  # with real work — while keeping peak memory bounded.
  #
  # cores must come down alongside it. It defaults to 0 ("use every core"), which
  # was right at max-jobs = 1 but would give 2 x 14 = 28 concurrent compilers
  # here. Pinning cores to 7 keeps the product at 14, i.e. one compiler per
  # thread total, which is the level the machine can actually feed.
  nix.settings = {
    max-jobs = 2;
    cores = 7;
  };

  # ── Graphics (Meteor Lake iGPU) ──────────────────────────────────────────────
  # No discrete GPU, so the iGPU carries all video decode and compute. The driver
  # packages come from nixos-hardware's common/cpu/intel/meteor-lake, imported in
  # flake.nix — don't restate them in hardware.graphics.extraPackages here.
  #
  # Deliberately *not* setting hardware.intelgpu, unlike framework/default.nix:
  #
  #   driver      — framework forces "xe" because Xe3/Panther Lake postdates i915.
  #                 Xe-LPG here is i915 territory and xe is still experimental for
  #                 Meteor Lake, so the "i915" default is the one we want.
  #   vaapiDriver — the meteor-lake module already pins this to intel-media-driver
  #                 with a plain assignment, so repeating it here would be a
  #                 conflicting definition, not a harmless duplicate. Worth knowing
  #                 why it matters: at the default (null) the module installs both
  #                 VA-API drivers, and its intel-ocl branch is gated on
  #                 enableAllFirmware, which base.nix sets — so the null default
  #                 would drag in intel-ocl, whose source tarball 404s at Intel.
  #
  # Pin the VA-API driver for userspace: libva's autodetection still guesses i965
  # on some Intel PCI IDs, which silently drops back to software decode. Safe to
  # set unconditionally — hyprland.nix only exports its own LIBVA_DRIVER_NAME
  # under the `nvidia` hmArg, which this host doesn't set.
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # ── TLP battery management ────────────────────────────────────────────────────
  # base.nix enables the service (powerManagement = "tlp"); all settings live here.
  services.tlp = {
    settings = {
      TLP_DEFAULT_MODE = "AC";
      CPU_SCALING_GOVERNOR_ON_AC = lib.mkDefault "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = lib.mkDefault "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = lib.mkDefault "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = lib.mkDefault "power";
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
  # Limine (themed menu + generation cap) comes from ../common/optional/limine.nix.
  boot = {
    # Portable USB drive: install to the ESP fallback path (\EFI\BOOT\BOOTX64.EFI)
    # rather than writing NVRAM entries on whatever machine it happens to be
    # plugged into during a rebuild. With canTouchEfiVariables = false, Limine's
    # efiInstallAsRemovable defaults true, so it installs to that fallback path.
    #
    # Rebuilds therefore never touch NVRAM — so the firmware must be pointed at
    # the fallback path by hand, once per machine. On the ThinkBook that's a
    # manually created "NixOS Limine" entry (see efibootmgr note below); the
    # generic firmware "USB HDD:" option also reaches it.
    loader.efi.canTouchEfiVariables = false;
    initrd.systemd.enable = true;

    # Windows lives on the ThinkBook's internal NVMe, which has its own ESP —
    # a different disk from the USB we boot Limine off, so `boot():` can't reach
    # it. Target that ESP by its partition GUID (nvme0n1p1, the 260M EFI system
    # partition). Update the guid() if the internal disk is ever repartitioned.
    loader.limine.extraEntries = ''
      /Windows
          protocol: chainload
          path: guid(27906f6e-7cb3-474f-be1e-dde5a6c2f113):/EFI/Microsoft/Boot/bootmgfw.efi
    '';
  };

  # The ThinkBook may prune the USB's NVRAM entry after booting without the drive
  # attached, and rebuilds can't recreate it (canTouchEfiVariables = false), so
  # efibootmgr lets us re-pin it from the running system:
  #   sudo efibootmgr --create --disk /dev/sda --part 1 \
  #     --label "NixOS Limine" --loader '\EFI\BOOT\BOOTX64.EFI'
  environment.systemPackages = [ pkgs.efibootmgr ];

  # ── Networking ───────────────────────────────────────────────────────────────
  networking.hostName = "work-laptop";

  system.stateVersion = "24.11";
}
