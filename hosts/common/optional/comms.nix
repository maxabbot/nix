{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Slack and Discord bundle their own Electron, and 26.05's builds lag far
    # enough that it's EOL (Slack 4.49: Electron 41; Discord 1.0.159: 42) —
    # unpatched Chromium rendering untrusted messages and embeds. Unstable
    # tracks upstream releases (2026-11-27: Electron 43 and 44). Move back to
    # the stable set once a release branch carries a supported Electron.
    unstable.slack
    unstable.discord
    zoom-us
  ];
}
