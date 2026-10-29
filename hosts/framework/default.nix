# hosts/framework/default.nix — Framework Laptop 13 Pro (Intel Core Ultra X7 358H,
# Panther Lake, Arc Xe3 iGPU). Personal + work machine: the home-desktop feature
# set minus the things that only make sense on a desktop with a discrete GPU
# (nvidia, cuda, fan2go, the Apollo streaming *host* — it gets moonlight.nix,
# the client half, instead).
#
# Platform support — kernel params, the Framework EC kmod, framework-tool, fwupd,
# fprintd, acpilight, the headphone-noise and Ethernet-card udev rules — comes
# from nixos-hardware's `framework-intel-core-ultra-series3` module, imported
# from flake.nix alongside disko. Don't restate any of it here.
{ lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../modules/nixos/base.nix
    ../common/optional/development.nix
    ../common/optional/podman.nix
    ../common/optional/libvirt.nix
    ../common/optional/db-gui.nix
    ../common/optional/duckdb.nix
    ../common/optional/cloud-tools.nix
    ../common/optional/productivity.nix
    ../common/optional/creative-apps.nix
    ../common/optional/streaming-tools.nix
    ../common/optional/google-chrome.nix
    ../common/optional/comms.nix
    ../common/optional/onedrive.nix
    ../common/optional/pwas.nix
    ../common/optional/stylix.nix
    ../common/optional/gaming.nix
    ../common/optional/wine.nix
    ../common/optional/lan-mouse.nix
    ../common/optional/logitech.nix
    ../common/optional/moonlight.nix
    ../common/optional/tailscale.nix
    ../common/optional/limine.nix
    ../common/optional/plymouth.nix
    ../common/optional/sops.nix
    ../common/optional/btrfs.nix
  ];

  # ── Base ─────────────────────────────────────────────────────────────────────
  # powerManagement is left at base.nix's default (power-profiles-daemon) rather
  # than work-laptop's TLP: the DMS battery popout's profile buttons (batteryPlus)
  # need power-profiles-daemon, and
  # nixos-hardware's laptop module already backs off TLP when ppd is on. The
  # powersave specialisation below is where TLP's finer-grained knobs live, for
  # the days that need them.
  custom.base.enable = true;

  # ── Specialisations ───────────────────────────────────────────────────────────
  # Boot menu shows a "powersave" entry for aggressive battery conservation —
  # same idea as work-laptop's, but this host defaults to power-profiles-daemon,
  # so the specialisation has to swap the daemon out rather than just retune it.
  # Setting custom.base.powerManagement flips both services at once (base.nix
  # derives `power-profiles-daemon.enable` and `tlp.enable` from it).
  #
  # Trade-off worth knowing before picking this entry: with ppd gone, the
  # DMS battery popout's profile buttons stop working — they need
  # power-profiles-daemon. Power management becomes purely
  # declarative until you reboot into the default generation.
  specialisation.powersave.configuration = {
    system.nixos.tags = [ "powersave" ];

    custom.base.powerManagement = "tlp";

    services.tlp.settings = {
      # Treat AC like battery — the point of this entry is minimum draw, not
      # "fast when plugged in".
      TLP_DEFAULT_MODE = "BAT";
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "power";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # No turbo. On Panther Lake this is the single biggest lever: boost states
      # dominate package power under bursty desktop load.
      CPU_BOOST_ON_AC = 0;
      CPU_BOOST_ON_BAT = 0;
      CPU_HWP_DYN_BOOST_ON_AC = 0;
      CPU_HWP_DYN_BOOST_ON_BAT = 0;

      # ACPI platform profile — the firmware's own thermal/power envelope,
      # below anything the governor can reach on its own.
      PLATFORM_PROFILE_ON_AC = "low-power";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      # Runtime PM for PCIe devices, wifi power saving, and deeper ASPM.
      RUNTIME_PM_ON_AC = "auto";
      RUNTIME_PM_ON_BAT = "auto";
      PCIE_ASPM_ON_AC = "powersupersave";
      PCIE_ASPM_ON_BAT = "powersupersave";
      WIFI_PWR_ON_AC = 5;
      WIFI_PWR_ON_BAT = 5;

      # Audio codec sleeps after 1s idle. Left at 0 (no controller powersave)
      # because Framework's TRRS jack pops on codec wake — the headphone-noise
      # udev rule from nixos-hardware exists for the same reason.
      SOUND_POWER_SAVE_ON_AC = 1;
      SOUND_POWER_SAVE_ON_BAT = 1;
      SOUND_POWER_SAVE_CONTROLLER = "N";

      NMI_WATCHDOG = 0;
    };
  };

  # ── Nix builds ───────────────────────────────────────────────────────────────
  # base.nix caps max-jobs at 1 for the RAM-constrained hosts. Once the installed
  # RAM is known and comfortable (home-desktop uses "auto" at 62 GiB), raise it:
  #   nix.settings.max-jobs = "auto";

  # ── Graphics (Arc Xe3 iGPU) ──────────────────────────────────────────────────
  # There is no discrete GPU here, so the iGPU carries video decode, compute and
  # gaming. nixos-hardware's common/gpu/intel supplies the driver packages
  # (intel-media-driver + 32-bit sibling for Proton/Wine, intel-compute-runtime,
  # vpl-gpu-rt) — only its defaults need correcting, so don't add them by hand to
  # hardware.graphics.extraPackages here.
  hardware.intelgpu = {
    # Defaults to i915, which predates Xe3. Panther Lake needs the `xe` DRM
    # driver; the module also loads it in initrd for early KMS.
    driver = "xe";
    # Default (null) installs *both* VA-API drivers. The i965-era
    # intel-vaapi-driver only covers Gen8–11, and pulling it in also drags in
    # intel-ocl, whose source tarball 404s at Intel — an unbuildable closure.
    vaapiDriver = "intel-media-driver";
  };

  environment = {
    # Pin the VA-API driver — libva's autodetection still guesses i965 on some
    # Intel PCI IDs, which silently disables hardware decode.
    sessionVariables.LIBVA_DRIVER_NAME = "iHD";

    # Host-specific tools only. brightnessctl, ddcutil and smartmontools already
    # come from productivity.nix, and nixos-hardware supplies the Framework's own
    # firmware/EC tooling (framework-tool, fw-ectool, fwupd) — don't restate any
    # of them here.
    systemPackages = with pkgs; [
      # Moonlight (streams games from home-desktop's Apollo host) now comes from
      # ../common/optional/moonlight.nix, imported above — gaming-streaming.nix
      # stays out, since it also enables the Apollo *server*.

      # ── iGPU diagnostics ────────────────────────────────────────────────────
      # There's no nvidia-smi on this machine, so these are the only window into
      # what the Xe3 is doing.
      intel-gpu-tools # intel_gpu_top — per-engine iGPU utilisation
      libva-utils # vainfo — should report the iHD driver

      # ── Battery / thermals ──────────────────────────────────────────────────
      # `sudo powertop --calibrate` once, then `powertop` to find what's keeping
      # the package out of its deep C-states.
      powertop
      # smartctl doesn't surface NVMe thermal-throttle counters or the Framework
      # SSD's power-state table; `nvme smart-log /dev/nvme0` does.
      nvme-cli

      # ── Secure Boot ─────────────────────────────────────────────────────────
      # Needed for the `sbctl create-keys` / `sbctl enroll-keys` steps referenced
      # in the boot block below, before Limine's secureBoot can be switched on.
      sbctl
    ];
  };

  # ── Speakers ─────────────────────────────────────────────────────────────────
  # nixos-hardware ships `hardware.framework.laptop13.audioEnhancement` (a
  # PipeWire filter chain: bass extension, loudness compensation, EQ). Left OFF
  # deliberately — upstream tuned it for the classic Framework 13 chassis and
  # says the Pro's speakers need different values, so enabling it here would
  # apply the wrong EQ curve. Revisit if a Pro profile lands upstream.

  # ── Fingerprint reader ───────────────────────────────────────────────────────
  # services.fprintd comes from nixos-hardware. Enrol once per finger with
  # `fprintd-enroll`, then verify with `fprintd-verify`.
  #
  # Every PAM service's fprintAuth defaults to on, which puts pam_fprintd ahead
  # of the password: it waits for a finger, or its timeout, before the password
  # is tried. Kept for sudo and polkit; off for:
  #   - login, which SDDM's stack substacks: a fingerprint login hands
  #     gnome-keyring no password, so the login keyring stays locked.
  #   - hyprlock, which talks to fprintd itself (the auth block that
  #     modules/home/apps.nix adds on fprintd hosts), so the finger and the
  #     password field work at the same time. Both at once would fight over
  #     the reader.
  security.pam.services = {
    login.fprintAuth = false;
    hyprlock.fprintAuth = false;
  };

  # ── Bootloader ───────────────────────────────────────────────────────────────
  # Limine (themed menu + generation cap) comes from ../common/optional/limine.nix.
  # No Windows chainload entry — this disk is Linux-only (see disk-config.nix).
  boot = {
    loader.efi.canTouchEfiVariables = true;

    # Required for the LUKS passphrase prompt: the systemd initrd unlocks
    # /dev/mapper/cryptroot (device entry generated by disko) and hands the
    # prompt to plymouth/console cleanly.
    initrd.systemd.enable = true;

    # Secure Boot: the Framework ships with it enabled and Setup Mode available
    # from BIOS. Once the sbctl key steps in limine.nix's header have been run,
    # flip this on and rebuild — Limine signs with the same sbctl keys.
    # loader.limine.secureBoot.enable = true;

    # TPM2 unlock: the initrd tries a TPM2 token in the LUKS header first and
    # falls back to the passphrase prompt when there is none or the TPM won't
    # release it. Enrol only once Secure Boot is on, since PCR 7 measures the
    # Secure Boot state:
    #   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 \
    #     /dev/disk/by-partlabel/disk-nvme-luks
    # PCR 7 alone, because the kernel and initrd change with every rebuild.
    # That's safe once Secure Boot is on: Limine then enrols its own config
    # and checks every kernel and initrd hash, so nothing on the ESP can be
    # swapped. Without a PIN the disk unlocks for anyone who powers the
    # machine on, and the login password is what's left; add
    # --tpm2-with-pin=yes to keep a short PIN at boot. The passphrase keyslot
    # stays as the fallback. A Secure Boot database update (fwupd's dbx)
    # changes PCR 7: unlock with the passphrase once, then re-enrol with
    # --wipe-slot=tpm2 added.
    initrd.luks.devices.cryptroot.crypttabExtraOpts = [ "tpm2-device=auto" ];
  };

  # ── Lid / suspend ────────────────────────────────────────────────────────────
  # Closing the lid on battery suspends, then hibernates to the @swap swapfile
  # (disk-config.nix) after HibernateDelaySec, so a laptop left shut in a bag
  # doesn't drain flat. On AC it only suspends. hypridle's 15-minute idle
  # suspend follows HandleLidSwitch (modules/home/wm/hyprland.nix), and
  # HibernateOnACPower = false holds its countdown while plugged in, so a
  # docked machine left idle stays suspended. DMS's power menu stays plain
  # suspend.
  #
  # No resume= or resume_offset: when systemd-sleep hibernates it records the
  # swapfile's location in the HibernateLocation EFI variable, and the systemd
  # initrd resumes from it once LUKS is unlocked. Secure Boot won't block it
  # either: the kernel is built without the lockdown LSM.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };
  systemd.sleep.settings.Sleep = {
    HibernateDelaySec = "2h";
    HibernateOnACPower = false;
  };

  # ── Battery charge limit ─────────────────────────────────────────────────────
  # Stop charging at 80%: a cell held at 100% on a desk wears fastest. The
  # limit lives in the EC, written through framework_laptop's
  # charge_control_end_threshold (nixos-hardware loads the kmod). The attribute
  # only appears once both the ACPI battery driver and framework_laptop have
  # loaded, in whichever order udev gets to them, hence the retry. For a full
  # charge before a trip, until the next boot:
  #   echo 100 | sudo tee /sys/class/power_supply/BAT1/charge_control_end_threshold
  systemd.services.battery-charge-limit = {
    description = "Cap battery charge at 80%";
    wantedBy = [ "multi-user.target" ];
    startLimitBurst = 10;
    startLimitIntervalSec = 60;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.runtimeShell} -c 'echo 80 > /sys/class/power_supply/BAT1/charge_control_end_threshold'";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };

  # ── Networking ───────────────────────────────────────────────────────────────
  # iwd handles roaming between APs noticeably better than wpa_supplicant, which
  # matters on a machine that moves between home and the office. NetworkManager
  # (base.nix) stays in charge of profiles; iwd is only the wifi backend.
  networking = {
    hostName = "framework";
    networkmanager.wifi.backend = lib.mkDefault "iwd";
    wireless.iwd.enable = true;
  };

  system.stateVersion = "26.05";
}
