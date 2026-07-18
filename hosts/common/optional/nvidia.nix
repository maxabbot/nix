{ config, pkgs, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    # The kernel-suspend-notifier path (default on for open modules + driver
    # >= 595) intermittently fails to restore VRAM on resume — green stale
    # framebuffer even on the TTY. Force the systemd nvidia-suspend/resume
    # services instead.
    powerManagement.kernelSuspendNotifier = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
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
