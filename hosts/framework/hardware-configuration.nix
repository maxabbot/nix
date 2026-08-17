# hosts/framework/hardware-configuration.nix
#
# PLACEHOLDER — written ahead of the machine being installed. Regenerate on the
# target hardware and merge anything new in:
#   sudo nixos-generate-config --no-filesystems --show-hardware-config
#
# The values below are the standard Framework 13 / Panther Lake set; most of the
# real platform tuning (kernel params, EC module, fwupd, fprintd, acpilight)
# comes from nixos-hardware's framework-intel-core-ultra-series3 module, wired
# in from flake.nix — do not duplicate it here.
#
# NOTE: fileSystems are NOT defined here — disko (disk-config.nix) manages them,
# including the LUKS mapping for /dev/mapper/cryptroot.
{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    initrd = {
      # thunderbolt: the Framework's USB-C ports are Thunderbolt/USB4, so an
      # expansion-card NVMe or boot-time keyboard can hang off them.
      availableKernelModules = [
        "xhci_pci"
        "thunderbolt"
        "nvme"
        "usb_storage"
        "uas"
        "usbhid"
        "sd_mod"
      ];
      kernelModules = [ ];
    };
    # Intel Core Ultra X7 358H (Panther Lake). The Xe3 iGPU's `xe` DRM module is
    # loaded in initrd by nixos-hardware (hardware.intelgpu.driver, set in
    # default.nix) — don't restate it here.
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
  };

  # No swap partition (LUKS full-disk, zram instead — see disk-config.nix).
  swapDevices = [ ];

  hardware.cpu.intel = {
    npu.enable = true; # Panther Lake NPU (intel_vpu)
    updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
