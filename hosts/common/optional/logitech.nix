# Solaar — manager for Logitech Unifying/Bolt peripherals (the MX Ergo S
# trackball): button remapping, pointer/scroll speed, per-device rules and
# battery level in the tray.
#
# hardware.logitech.wireless installs three things: solaar (the GTK app, from
# enableGraphical), ltunify (CLI pairing for the older Unifying receivers) and
# logitech-udev-rules. The rules package is the load-bearing part — it ships as
# 42-logitech-unify-permissions.rules, early enough for its TAG+="uaccess" to be
# picked up by 73-seat-late.rules, so the receiver's hidraw node is writable by
# the logged-in user. (This is the same ordering trap as the Vial rules in
# hosts/home-desktop/default.nix: services.udev.extraRules lands in
# 99-local.rules, which runs far too late for uaccess.)
#
# Solaar re-applies its stored per-device settings each time a device connects,
# so it has to stay resident. The tray unit lives in modules/home/wm/hyprland.nix
# next to the other applets, gated on enableGraphical so it only appears on hosts
# that import this file.
_: {
  hardware.logitech.wireless = {
    enable = true;
    enableGraphical = true;
  };
}
