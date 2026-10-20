{ config, pkgs, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement = {
      enable = true;
      finegrained = false;
      # The kernel-suspend-notifier path (default on for open modules + driver
      # >= 595) intermittently fails to restore VRAM on resume — green stale
      # framebuffer even on the TTY. Force the systemd nvidia-suspend/resume
      # services instead.
      kernelSuspendNotifier = false;
    };
    open = true;
    nvidiaSettings = true;
    # 615.78.08, pulled forward by version+hash rather than by channel: the
    # nixos-26.05 pin tops out at 595.71.05 on every channel, and 610/615 live
    # only in unstable (hashes copied from its `new_feature` entry). mkDriver
    # builds it against *this* system's kernel, so the modules stay matched;
    # taking linuxPackages from another channel would not.
    #
    # The reason for moving at all is the semsurf explicit-sync failure on
    # resume (see the resume-probe capture of 2026-09-10): the driver fails to
    # restore the sync-FD semaphore surface, every atomic DRM commit then fails
    # EINVAL, and the session comes back lit but unable to present anything.
    # 610.57.04 did not fix it (failed again 2026-09-11); 615 is the next
    # gamble, not a known fix. Roll back to `nvidiaPackages.stable` (and
    # re-pin the kernel, see below) if it does not help either.
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version = "615.78.08";
      sha256_64bit = "sha256-Pj9t3cLudnoIGFMAr3vjyyhuznZpjS3eNSRZl4LQf/4=";
      sha256_aarch64 = "sha256-UHYBE1AYHoGgMfD9AS/jX+S+N8eCDWUft6qolK9Eejc=";
      openSha256 = "sha256-HBINiOjL0ZJLIAJeNIBYHBnwgUXtNwPPtnFpAI1YwF4=";
      settingsSha256 = "sha256-inDRpG02sdDgHmlqgu/DsgK8OFdOt1fZIYyXdhlGC/c=";
      persistencedSha256 = "sha256-RzeR6Ldct6MUxjnXRyThdh5Y3jjMehTVg85MtwuWNX4=";
    };
    nvidiaPersistenced = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    # Only driver components (VA-API) belong here — the Vulkan loader ships with
    # the driver, and vulkan-tools/validation-layers are CLI/dev tools that live
    # in gaming.nix's systemPackages where they actually land on PATH.
    extraPackages = with pkgs; [
      nvidia-vaapi-driver
      libva
      libva-utils
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];
  };

  boot = {
    # No kernel pin: base.nix's linuxPackages_latest (7.3) is used. The old
    # `linuxPackages_7_1` pin existed because 595 would not compile on 7.2
    # (os-interface.c calls strncpy without <string.h>); 610+ does, and the
    # attribute is gone from nixos-26.05 anyway, so the pin could not survive
    # the flake update regardless. it87 and xpadneo both build against 7.3.

    kernelParams = [
      "nvidia-drm.modeset=1"
      "nvidia-drm.fbdev=1"
    ];
    # NVreg_PreserveVideoMemoryAllocations=1 is set by the nvidia module itself
    # via hardware.nvidia.powerManagement.enable.
    initrd.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];
  };

  # sessionVariables alone covers login sessions (environment.d / PAM); a
  # duplicate environment.variables block previously set the first three again.
  # Hyprland's generated env.lua re-exports them inside the compositor (set via
  # the nvidia hmArg) — that copy is kept because it applies before any
  # session-manager environment is loaded.
  environment.sessionVariables = {
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    LIBVA_DRIVER_NAME = "nvidia";
    __GL_GSYNC_ALLOWED = "1";
    __GL_VRR_ALLOWED = "1";
  };
}
