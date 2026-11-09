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
# Metro serves the app's source to anyone who can reach it, so the port is
# open on every interface only on the desktop (trusted home LAN). On a laptop
# it's tailnet-only — a phone on the tailnet can still reach it, or use
# `adb reverse tcp:8081 tcp:8081` over USB, which needs no open port.
{ pkgs, machineType, ... }:
let
  ports.allowedTCPPorts = [ 8081 ];

  # Run Studio as a native Wayland client (its bundled JBR ships WLToolkit).
  # Under XWayland it takes one global scale from Xft.dpi, which on framework
  # is the internal panel's 2x, so it came out double-size on the 1x externals;
  # native, it scales per output like everything else. STUDIO_VM_OPTIONS is
  # merged over the bundled vmoptions, and replaces the per-user
  # ~/.config/Google/AndroidStudio*/studio64.vmoptions — put tweaks here
  # rather than in Help > Edit Custom VM Options.
  vmOptions = pkgs.writeText "studio64.vmoptions" ''
    -Dawt.toolkit.name=WLToolkit
  '';
  android-studio = pkgs.symlinkJoin {
    name = "android-studio-wayland-${pkgs.android-studio.version}";
    paths = [ pkgs.android-studio ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/android-studio --set STUDIO_VM_OPTIONS ${vmOptions}
    '';
  };
in
{
  environment.systemPackages = [ android-studio ];

  networking.firewall = if machineType == "laptop" then { interfaces.tailscale0 = ports; } else ports;
}
