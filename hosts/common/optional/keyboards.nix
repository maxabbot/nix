# keyboards.nix — configurator / flashing access for the programmable keyboards
# (NuPhy Air75 V3, splitkb Aurora Sofle v2 running Vial). Imported by the hosts
# the keyboards get plugged into (home-desktop, framework).
{ pkgs, ... }:
{
  # QMK udev rules (bootloader/DFU access for flashing the Sofle).
  hardware.keyboard.qmk.enable = true;

  services.udev = {
    # NuPhy Air75 V3 — grants userspace hidraw access for nuphy.io configurator.
    # 0660 + input group instead of world-writable 0666; the primary user is in
    # "input" (base.nix). TAG+="uaccess" won't work here: extraRules lands in
    # 99-local.rules, after 73-seat-late.rules has already processed the tag.
    extraRules = ''
      KERNEL=="hidraw*", ATTRS{idVendor}=="19f5", ATTRS{idProduct}=="1028", MODE="0660", GROUP="input"
    '';

    # Vial (splitkb Aurora Sofle v2, 8d1d:ec32) — hidraw access for the
    # vial.rocks WebHID configurator. Unlike the NuPhy rule above this needs
    # TAG+="uaccess", so it can't live in extraRules (99-local.rules runs too
    # late); ship it as a package so the filename sorts before
    # 73-seat-late.rules. The serial match is Vial's magic prefix, common to
    # every Vial-enabled board, so this covers future ones too.
    packages = [
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
