# Expo / React Native — lets a phone on the LAN reach Metro, the dev server
# that a development build loads the app's JavaScript from.
#
# Also installs Android Studio (an FHS-wrapped upstream build, ~4.3 GiB),
# for its emulator and layout inspector. It manages its own SDK under
# ~/Android/Sdk, separate from the projects' read-only Nix SDKs.
#
# Otherwise this file only opens the port. The toolchain (Node, JDK, Android SDK/NDK)
# lives in each project's own flake.nix, pinned to that project's Expo SDK,
# and direnv loads it on `cd`. adb needs no config here: systemd ≥ 258
# grants USB access to adb/fastboot devices through uaccess.
#
# Metro serves the app's source to anyone who can reach it, so this is
# imported on home-desktop only (trusted home LAN). Laptops on other networks
# can run `adb reverse tcp:8081 tcp:8081` over USB instead, which needs no
# open port.
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.android-studio ];

  networking.firewall.allowedTCPPorts = [ 8081 ];
}
