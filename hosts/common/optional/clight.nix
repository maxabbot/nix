# hosts/common/optional/clight.nix — ambient-light auto-brightness for the
# internal panel (framework: the lid has an iio light sensor).
#
# Clight (user daemon) reads the sensor through clightd (system D-Bus service)
# and sets the backlight. Its Control Center tile is DMS's first-party
# dankClight plugin, installed by modules/home/wm/dms-plugins.nix wherever this
# service is enabled: pause/resume, a manual capture, and live settings.
#
# Only the backlight module does anything. Clight also does gamma, dimming,
# DPMS, keyboard backlight and screen-content compensation; each of those
# already has an owner here or wasn't wanted:
#   • gamma    — gammastep (home/max/desktop.nix)
#   • dimmer/dpms — hypridle
#   • keyboard — would also switch the keyboard backlight off after 15 s idle
#   • screen   — samples screen content; light level alone
#
# DPMS is the exception: on, but with timeouts of -1, which Clight treats as
# permanently paused. With dimmer and DPMS both disabled Clight force-disables
# inhibit too, and its Pause method lives in the PM module that only loads
# with inhibit — so the tile's Pause/Inhibit buttons failed ("Invalid
# argument"). Inhibit also makes Clight try to take org.freedesktop.ScreenSaver
# (REPLACE_EXISTING); hypridle starts first at login and kept it in testing,
# so Clight falls back to watching it. Don't order clight after hypridle to
# force that: hypridle is after graphical-session.target, which is after
# clight, and systemd breaks the cycle by dropping clight's start job.
#
# The package also ships an XDG autostart entry that runs a bare `clight` —
# Clight's defaults: dimmer, screen-off via clightd (which hypridle can't see
# or undo, so the panel stays black), gamma, fades, a curve down to 0%. That
# second copy is what blacked the screen out; it's hidden below so only the
# configured service runs.
#
# Fades are off: clightd 5.9's smooth Set to the level the panel is already
# at drops it to raw 0 and leaves it there (reproduced: 3% → fade to 3% → 0),
# which a Clight restart or a capture in unchanged light triggers.
#
# Internal panel only: clightd is built without DDC (overlays/default.nix),
# so docked monitors stay with the DMS slider instead of two writers fighting
# over them.
#
# Manual changes (brightness keys, the DMS slider) hold until the next capture
# — every 10 min on AC by day, 20 on battery — Clight doesn't learn from them.
# Pause it from the tile to keep a manual level.
{ config, ... }:
{
  services.clight = {
    enable = true;
    settings = {
      gamma.disabled = true;
      dimmer.disabled = true;
      dpms.timeouts = [
        (-1)
        (-1)
      ];
      backlight.no_smooth_transition = true;
      keyboard.disabled = true;
      screen.disabled = true;
      # Clight's default curves start at 0.0, which in the dark writes raw 0
      # and blacks the panel out. Same curves, lifted at the bottom to 3% — the
      # brightness-down key's floor too (hyprland.lua).
      sensor = {
        ac_regression_points = [
          0.03
          0.15
          0.29
          0.45
          0.61
          0.74
          0.81
          0.88
          0.93
          0.97
          1.0
        ];
        batt_regression_points = [
          0.03
          0.15
          0.23
          0.36
          0.52
          0.59
          0.65
          0.71
          0.75
          0.78
          0.80
        ];
      };
    };
  };

  home-manager.users.${config.custom.base.username}.xdg.configFile."autostart/clight.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Clight
    Hidden=true
  '';

  # Clight's day/night timing (capture intervals) — and its module asserts on
  # these. Christchurch, as `location` in flake.nix sharedHmArgs (gammastep's);
  # keep the two in sync.
  location = {
    latitude = -43.53;
    longitude = 172.64;
  };
}
