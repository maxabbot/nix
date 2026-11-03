# WinBoat — a Windows 11 guest (dockur/windows, QEMU/KVM in a container) whose
# apps appear as native windows over RDP. Here for Power BI Desktop, which is
# Windows-only; see docs/guides/framework-migration.md §7 (framework only).
#
# Runs on Podman, chosen during WinBoat's first-run setup — not Docker:
# podman.nix's dockerCompat refuses to coexist with virtualisation.docker. The
# nixpkgs package wraps podman-compose and FreeRDP onto its own PATH, so
# nothing else is needed. USB passthrough doesn't work under Podman.
#
# Before setup, create the install folder and `chattr +C` it: the guest disk is
# a 30–50 GB image, and btrfs copy-on-write fragments it badly. The attribute
# only applies to files created afterwards.
{ config, pkgs, ... }:
{
  assertions = [
    {
      assertion = config.virtualisation.podman.enable;
      message = "winboat.nix expects podman.nix to be imported";
    }
  ];

  environment.systemPackages = [ pkgs.winboat ];
}
