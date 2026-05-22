{ pkgs, ... }:
{
  virtualisation.libvirtd = {
    enable = true;
    qemu.runAsRoot = false;
  };

  environment.systemPackages = with pkgs; [
    libvirt
    qemu
    virt-manager
    dnsmasq
  ];
}
