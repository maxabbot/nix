# keyboards.nix — configurator / flashing access for the programmable keyboards
# (NuPhy Air75 V3, splitkb Aurora Sofle v2 running Vial). Imported by the hosts
# the keyboards get plugged into (home-desktop, framework).
{ pkgs, ... }:
{
  # QMK udev rules (bootloader/DFU access for flashing the Sofle).
  hardware.keyboard.qmk.enable = true;

  # Both rules use TAG+="uaccess" (access for whoever holds the active seat),
  # not a group: the "input" group would also expose every keyboard's evdev
  # node (base.nix). uaccess can't live in extraRules — that lands in
  # 99-local.rules, after 73-seat-late.rules has processed the tag — so each
  # ships as a package whose filename sorts before it.
  services.udev = {
    packages = [
      # NuPhy Air75 V3 — hidraw access for the nuphy.io configurator.
      (pkgs.writeTextFile {
        name = "nuphy-udev-rules";
        destination = "/etc/udev/rules.d/59-nuphy.rules";
        text = ''
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="19f5", ATTRS{idProduct}=="1028", MODE="0660", TAG+="uaccess"
        '';
      })
      # Vial (splitkb Aurora Sofle v2, 8d1d:ec32) — hidraw access for the
      # vial.rocks WebHID configurator. The serial match is Vial's magic
      # prefix, common to every Vial-enabled board, so this covers future ones.
      (pkgs.writeTextFile {
        name = "vial-udev-rules";
        destination = "/etc/udev/rules.d/59-vial.rules";
        text = ''
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:f64c2b3c*", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
        '';
      })
    ];
  };
}
