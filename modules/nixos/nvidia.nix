# modules/nixos/nvidia.nix — NVIDIA drivers, CUDA, and kernel configuration.
# Mirrors system/roles/nvidia from the Arch Ansible layer.
# Targets RTX 40-series (open kernel module supported).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.nvidia;
in
{
  options.custom.nvidia = {
    enable = lib.mkEnableOption "NVIDIA driver stack";

    open = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use NVIDIA's open-source kernel module (recommended for RTX 30+).";
    };

    cuda.enable = lib.mkEnableOption "CUDA / cuDNN stack";
  };

  config = lib.mkIf cfg.enable {
    # ── Driver ─────────────────────────────────────────────────────────────────
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      open = cfg.open;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    # ── OpenGL / Vulkan (32-bit for Steam / Wine) ──────────────────────────────
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        nvidia-vaapi-driver
        libva
        libva-utils
        vulkan-tools
        vulkan-validation-layers
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        libva
      ];
    };

    # ── Kernel parameters ──────────────────────────────────────────────────────
    boot.kernelParams = [
      "nvidia-drm.modeset=1"
      "nvidia-drm.fbdev=1"
    ];
    boot.initrd.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];

    # ── Wayland-specific NVIDIA env vars ───────────────────────────────────────
    # environment.variables = system-wide (SDDM greeter sees these before login)
    # environment.sessionVariables = per-session (user apps)
    environment.variables = {
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      GBM_BACKEND = "nvidia-drm";
      LIBVA_DRIVER_NAME = "nvidia";
    };
    environment.sessionVariables = {
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      GBM_BACKEND = "nvidia-drm";
      LIBVA_DRIVER_NAME = "nvidia";
      __GL_GSYNC_ALLOWED = "1";
      __GL_VRR_ALLOWED = "1";
    };

    # ── CUDA stack ─────────────────────────────────────────────────────────────
    environment.systemPackages = lib.mkIf cfg.cuda.enable (
      with pkgs.cudaPackages;
      [
        cuda_nvcc
        cudnn
        pkgs.clinfo
      ]
    );

    # ── nvidia-persistenced (keeps GPU awake between compute workloads) ────────
    hardware.nvidia.nvidiaPersistenced = true;
  };
}
