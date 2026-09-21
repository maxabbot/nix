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
#
# ── First run on a fresh machine ────────────────────────────────────────────
# Two things here are device state, not config, and a rebuild from this flake
# will NOT restore them — same shape as the one-time `tailscale up` in
# tailscale.nix:
#
#   1. Pair the trackball to a Bolt receiver (Solaar GUI, or `solaar pair`).
#      Pairings live in the receiver's own flash. Note that one device can
#      occupy several of the six slots if it has been re-paired repeatedly;
#      `solaar show` lists them and `solaar -D <receiver hidraw> unpair <slot>`
#      reclaims the duplicates. Pass -D whenever two receivers are plugged in,
#      or the 1..6 slot number is ambiguous across them.
#
#   2. Divert every button that config/solaar/rules.yaml has a rule for —
#      currently just the one:
#        solaar config "MX Ergo S" divert-keys "DPI Switch" Diverted
#      Diversion is stored in ~/.config/solaar/config.yaml, which Solaar owns
#      and rewrites (DPI, battery, diverted keys), so it can't be declared the
#      way rules.yaml is. Diverting a button also suppresses its normal
#      function, so divert only what a rule actually handles.
#
# That second command needs Solaar >= 1.1.20 to stick: on 1.1.19 it reaches the
# device but dies before saving, and reverts at the next daemon restart. See the
# solaar override in overlays/default.nix.
_: {
  hardware.logitech.wireless = {
    enable = true;
    enableGraphical = true;
  };
}
