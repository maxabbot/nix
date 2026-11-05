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
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../modules/nixos/base.nix
    ../common/optional/development.nix
    ../common/optional/podman.nix
    ../common/optional/libvirt.nix
    ../common/optional/winboat.nix
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
    ../common/optional/keyboards.nix
    ../common/optional/clight.nix
    ../common/optional/moonlight.nix
    ../common/optional/tailscale.nix
    ../common/optional/limine.nix
    ../common/optional/plymouth.nix
    ../common/optional/sops.nix
    ../common/optional/btrfs.nix
  ];

  # ── Base ─────────────────────────────────────────────────────────────────────
  # powerManagement is left at base.nix's default (power-profiles-daemon) rather
  # than TLP: the DMS battery popout's profile buttons (batteryPlus)
  # need power-profiles-daemon, and
  # nixos-hardware's laptop module already backs off TLP when ppd is on. The
  # powersave specialisation below is where TLP's finer-grained knobs live, for
  # the days that need them.
  custom.base.enable = true;

  # ── Specialisations ───────────────────────────────────────────────────────────
  # Boot menu shows a "powersave" entry for aggressive battery conservation.
  # This host defaults to power-profiles-daemon, so the specialisation has to
  # swap the daemon out for TLP rather than just retune it.
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

  # ── Idle power (default entry) ───────────────────────────────────────────────
  # What the powersave entry gets from TLP, for the everyday ppd entry too:
  # powertop (2026-11-02) flagged all three as untuned there. Audio is already
  # handled — snd_hda_intel's power_save is 10 s out of the box.
  #  - PCI runtime PM: idle devices (NVMe, Wi-Fi, chipset) may power down.
  #    Not the Bluetooth chip (8086:e476): it times out entering D3 — see the
  #    btintel_pcie hibernate hook below — so it stays on.
  #  - No NMI watchdog: a debugging aid whose per-CPU timer costs wakeups.
  #  - Dirty pages flushed every 15 s rather than 5, so the NVMe sleeps longer.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{device}!="0xe476", TEST=="power/control", ATTR{power/control}="auto"
  '';
  boot = {
    kernelParams = [ "nmi_watchdog=0" ];
    kernel.sysctl."vm.dirty_writeback_centisecs" = 1500;
  };

  # ── Fonts ────────────────────────────────────────────────────────────────────
  # Microsoft core fonts (Georgia, Times New Roman, Arial, …) — the CV build's
  # Puppeteer render expects Georgia, same as home-desktop. Merges with
  # base.nix's fonts.packages; unfree is already allowed flake-wide.
  fonts.packages = [ pkgs.corefonts ];

  # ── DDC/CI ───────────────────────────────────────────────────────────────────
  # Loads i2c-dev and grants i2c-bus access so the DMS brightness slider can
  # drive *external* monitors (the docked Philips pair) through ddcutil. The
  # internal panel is unaffected; it goes through the backlight interface.
  hardware.i2c.enable = true;

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

  # ── Fingerprint reader ───────────────────────────────────────────────────────
  # services.fprintd comes from nixos-hardware. Enrol once per finger with
  # `fprintd-enroll`, then verify with `fprintd-verify`.
  #
  # Every PAM service's fprintAuth defaults to on, which puts pam_fprintd ahead
  # of the password: it waits for a finger, or its timeout, before the password
  # is tried. Kept for sudo and polkit; off for:
  #   - login (the TTY) and greetd (the DMS greeter): a fingerprint login
  #     hands gnome-keyring no password, so the login keyring stays locked.
  #     The greeter reads /etc/pam.d/greetd to decide whether to offer the
  #     finger, so with it off there it asks for the password alone.
  #   - dankshell (the DMS lock's password stack): the lock runs its own
  #     fprintd stack alongside it (enableFprint, modules/home/wm/dms.nix), so
  #     the finger and the password field work at the same time. Both at once
  #     would fight over the reader.
  security.pam.services = {
    login.fprintAuth = false;
    greetd.fprintAuth = false;
    dankshell.fprintAuth = false;
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

    # Secure Boot: Limine signs itself with the sbctl keys in /var/lib/sbctl,
    # enrolled 2026-11-03 (owner GUID 25f76c52…, Microsoft + firmware keys
    # kept) per limine.nix's header. A reinstall without those keys needs
    # the header's create/enroll steps again before this builds.
    loader.limine.secureBoot.enable = true;

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
    #
    # Enrolled 2026-11-03 with a PIN. Each of these asks for the passphrase,
    # which none of them changes (that's `cryptsetup luksChangeKey`):
    #   change the PIN, or add one:  the enrol command + --wipe-slot=tpm2
    #                                + --tpm2-with-pin=yes
    #   drop the PIN:                the enrol command + --wipe-slot=tpm2
    #   passphrase only again:       sudo systemd-cryptenroll --wipe-slot=tpm2 \
    #                                  /dev/disk/by-partlabel/disk-nvme-luks
    initrd.luks.devices.cryptroot.crypttabExtraOpts = [ "tpm2-device=auto" ];
  };

  services = {
    # ── Speakers ───────────────────────────────────────────────────────────────
    # nixos-hardware ships `hardware.framework.laptop13.audioEnhancement` (a
    # PipeWire filter chain: bass extension, loudness compensation, EQ). Left OFF
    # deliberately — upstream tuned it for the classic Framework 13 chassis and
    # says the Pro's speakers need different values, so enabling it here would
    # apply the wrong EQ curve.
    #
    # Instead: Framework's own Windows tuning (Dolby DAX3, "Balanced" voicing),
    # rebuilt as a PipeWire filter chain — FIR speaker correction, PEQ,
    # multiband compressor, regulator, limiter. Generated once by
    # speaker-tuning-to-easyeffects (a113b2e) from
    # DEV_0285_SUBSYS_F111000F_PCI_SUBSYS_000FF111.xml in Framework's Windows
    # driver bundle v1.01 (2026-06-05), with
    #   dolby_to_pipewire.py <xml> --target-sink <sink> --no-activate
    # The conf is the generator's output unchanged, bar the @irs@ placeholder:
    # a WirePlumber smart filter, always on for the built-in analog sink, so
    # volume keys still drive the card itself. Its input node is still an
    # Audio/Sink, so DMS would list it as a second output; it's hidden from
    # DMS's output picker just after this block.
    # HDMI, USB and Bluetooth bypass it; the headphone jack doesn't (it's a port
    # on the same sink), so wired headphones get the speaker EQ too. It can't
    # be bypassed at runtime — PipeWire won't let a client unload it — so A/B
    # means a rebuild. (Tried as a selectable virtual sink to compare; the
    # Dolby version won, 2026-11-03.) The conf is marked nofail: if an LV2
    # plugin is missing, PipeWire just plays unprocessed.
    pipewire = {
      extraLv2Packages = [ pkgs.lsp-plugins ];
      configPackages = [
        (pkgs.writeTextDir "share/pipewire/pipewire.conf.d/60-dolby-speakers.conf" (
          builtins.replaceStrings [ "@irs@" ] [ "${../../config/pipewire/Dolby_Balanced.irs}" ] (
            builtins.readFile ../../config/pipewire/Dolby_Balanced.conf
          )
        ))
      ];
    };

    # ── Login greeter ──────────────────────────────────────────────────────────
    # Same panel mode and 2x scale as the session (hmArgs primary in flake.nix),
    # so the greeter doesn't come up at Hyprland's guess. Appended to
    # productivity.nix's greeter config.
    displayManager.dms-greeter.compositor.customConfig = ''
      hl.monitor({ output = "eDP-1", mode = "2880x1920@120", position = "0x0", scale = 2 })
    '';

    # ── Lid / suspend ──────────────────────────────────────────────────────────
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
    #
    # Power button: a tap suspends (logind's default is poweroff, and the button
    # doubles as the fingerprint reader, so it gets brushed); holding it for
    # logind's long-press threshold (~5 s) powers off.
    logind.settings.Login = {
      HandlePowerKey = "suspend";
      HandlePowerKeyLongPress = "poweroff";
      HandleLidSwitch = "suspend-then-hibernate";
      HandleLidSwitchExternalPower = "suspend";
      HandleLidSwitchDocked = "ignore";
    };
  };

  # The Dolby filter's input node (Speakers above) stays out of DMS's output
  # picker; see custom.hm.dms.hiddenOutputs in modules/home/wm/dms.nix.
  home-manager.users.${config.custom.base.username}.custom.hm.dms.hiddenOutputs = [
    "effect_input.Dolby_Balanced"
  ];

  # The hibernate half of the lid's suspend-then-hibernate (Lid / suspend above).
  systemd.sleep.settings.Sleep = {
    HibernateDelaySec = "2h";
    HibernateOnACPower = false;
  };

  # The Intel PCIe Bluetooth chip (btintel_pcie) times out entering D3 at the
  # hibernate power-off ("Timeout … on alive interrupt for D3 entry") and its
  # poweroff callback returns -EBUSY, which the kernel takes for a wakeup and
  # rolls the hibernation back — after the image is written, so the machine
  # just comes back. Unload the driver around the hibernate stage only:
  # suspend-then-hibernate runs hooks per stage with $2 = suspend-then-hibernate
  # and SYSTEMD_SLEEP_ACTION naming the stage, so plain suspend keeps Bluetooth.
  # Drop this once `systemctl hibernate` works without it on a newer kernel.
  environment.etc."systemd/system-sleep/btintel-pcie-hibernate".source =
    pkgs.writeShellScript "btintel-pcie-hibernate" ''
      case "''${SYSTEMD_SLEEP_ACTION:-$2}" in
        hibernate | hybrid-sleep) ;;
        *) exit 0 ;;
      esac
      case "$1" in
        pre) ${pkgs.kmod}/bin/modprobe -r btintel_pcie || true ;;
        post) ${pkgs.kmod}/bin/modprobe btintel_pcie || true ;;
      esac
    '';

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
  # (networking.hostName comes from mkHost in flake.nix.)
  networking = {
    networkmanager.wifi.backend = lib.mkDefault "iwd";
    wireless.iwd.enable = true;
  };

  system.stateVersion = "26.05";
}
