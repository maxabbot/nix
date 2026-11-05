# hosts/home-desktop/default.nix — Gaming/desktop workstation (RTX 40-series, Hyprland).
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../modules/nixos/base.nix
    ../common/optional/development.nix
    ../common/optional/podman.nix
    ../common/optional/expo.nix
    ../common/optional/libvirt.nix
    ../common/optional/db-gui.nix
    ../common/optional/duckdb.nix
    ../common/optional/cloud-tools.nix
    ../common/optional/productivity.nix
    ../common/optional/creative-apps.nix
    ../common/optional/streaming-tools.nix
    ../common/optional/google-chrome.nix
    ../common/optional/comms.nix
    ../common/optional/onedrive.nix
    ../common/optional/pwas.nix
    ../common/optional/stylix.nix
    ../common/optional/nvidia.nix
    ../common/optional/cuda.nix
    ../common/optional/gaming.nix
    ../common/optional/wine.nix
    ../common/optional/gaming-streaming.nix
    ../common/optional/fan2go.nix
    ../common/optional/lan-mouse.nix
    ../common/optional/logitech.nix
    ../common/optional/keyboards.nix
    ../common/optional/tailscale.nix
    ../common/optional/limine.nix
    ../common/optional/plymouth.nix
    ../common/optional/sops.nix
    ../common/optional/btrfs.nix
  ];

  # ── Base ─────────────────────────────────────────────────────────────────────
  # Fan control is fan2go (../common/optional/fan2go.nix), for moving-average
  # temperature smoothing — fancontrol only point-sampled and hunted on CPU spikes.
  custom.base.enable = true;

  # ── Steam gamescope session (greeter "Steam" entry) ──────────────────────────
  # gaming.nix enables gamescopeSession but leaves args empty, so gamescope
  # defaults to 720p @ 60 Hz and may render to the wrong connector — hence the
  # off resolution and lag on this 1440p/165 Hz panel. Pin the DP-3 gaming mode
  # (this is host-specific, which is why it lives here and not in shared
  # gaming.nix, which framework imports too). Matches DP-3's native mode.
  # --rt requests realtime scheduling for lower input latency.
  programs.steam.gamescopeSession.args = [
    "-W"
    "2560"
    "-H"
    "1440"
    "-r"
    "165"
    "-O"
    "DP-3"
    "--rt"
  ];

  services = {
    # ── Audio ──────────────────────────────────────────────────────────────────
    # Default sink is the Built-in analog line out for general apps.
    pipewire.wireplumber.extraConfig = {
      # Make the onboard analog line-out the default sink. WirePlumber picks the
      # highest-priority node as the auto-default, so raise analog above the
      # NVIDIA HDMI outputs. NOTE: a *manually* chosen default (pavucontrol or the
      # DMS output picker) is stored in ~/.local/state/wireplumber/default-nodes
      # and overrides priority — if HDMI ever sticks, clear it with
      # `wpctl set-default <analog-id>`.
      "20-default-sink" = {
        "node.rules" = [
          {
            matches = [ { "node.name" = "alsa_output.pci-0000_00_1f.3.analog-stereo"; } ];
            actions.update-props = {
              "priority.session" = 2000;
              "priority.driver" = 2000;
            };
          }
        ];
      };
    };

    # udev: the keyboard rules (NuPhy, Vial, QMK) live in
    # hosts/common/optional/keyboards.nix; the Bolt receiver's wakeup rule in
    # hosts/common/optional/logitech.nix, so each follows the device rather
    # than this host.
  };

  # ── Fonts ────────────────────────────────────────────────────────────────────
  # Microsoft core fonts (Georgia, Times New Roman, Arial, …) — the CV build's
  # Puppeteer render expects Georgia. Merges with base.nix's fonts.packages;
  # unfree is already allowed flake-wide.
  fonts.packages = [ pkgs.corefonts ];

  # ── Login greeter: DP-3 only ─────────────────────────────────────────────────
  # The greeter's Hyprland would otherwise light the rotated 4K monitor too and
  # centre the login there. Appended to productivity.nix's greeter config.
  services.displayManager.dms-greeter.compositor.customConfig = ''
    hl.monitor({ output = "DP-2", disabled = true })
  '';

  # ── DDC/CI ───────────────────────────────────────────────────────────────────
  # Loads i2c-dev and grants i2c-bus access (the "i2c" group / seat users) so the
  # DMS brightness slider can drive external-monitor brightness via ddcutil.
  hardware.i2c.enable = true;

  # ── RGB ──────────────────────────────────────────────────────────────────────
  # OpenRGB for the board/RAM/peripheral lighting: the package plus its udev
  # rules (device access for the logged-in user). The SMBus devices it drives
  # sit on the i2c buses enabled above. Desktop-only — the laptop has no RGB.
  services.udev.packages = [ pkgs.openrgb-with-all-plugins ];

  boot = {
    # ── ITE IT8689E hardware monitor (Gigabyte Z790 UD AX) ─────────────────────
    # Mainline it87 doesn't support this chip; the out-of-tree driver does.
    # Required for fan2go (and pwmconfig) to see the PWM controls.
    extraModulePackages = [ config.boot.kernelPackages.it87 ];
    kernelModules = [ "it87" ];

    # ── DDR5 SPD temp sensor breaks resume ──────────────────────────────────────
    # spd5118 (per-DIMM DDR5 temperature, kernel ≥6.11) fails its async resume
    # callback ("regmap_read failed: -6" / ENXIO) after suspend, which can stall
    # resume at a black screen. Per-DIMM RAM temps aren't used for anything here
    # (fan2go reads coretemp + it8628 only), so drop the module.
    blacklistedKernelModules = [ "spd5118" ];

    # ── aarch64 emulation ───────────────────────────────────────────────────────
    # Registers qemu-user as a binfmt_misc handler (and adds aarch64-linux to
    # nix's extra-platforms) so this box can build the Raspberry Pi's aarch64
    # SD image locally.
    binfmt.emulatedSystems = [ "aarch64-linux" ];

    # ── Bootloader ──────────────────────────────────────────────────────────────
    # Limine (themed menu + generation cap) comes from ../common/optional/limine.nix.
    loader.efi.canTouchEfiVariables = true;

    # Windows boots off the same ESP (its disk has no ESP of its own). systemd-boot
    # auto-detected it; Limine needs an explicit chainload entry.
    loader.limine.extraEntries = ''
      /Windows
          protocol: chainload
          path: boot():/EFI/Microsoft/Boot/bootmgfw.efi
    '';
  };

  # ── Secrets admin ────────────────────────────────────────────────────────────
  # This is the only host holding the admin age key (~/.config/sops/age/keys.txt),
  # so it is the only one that needs the tools: `sops secrets/*.yaml` here and in
  # the nixos-homelab repo, and `age-keygen` for new host keys (sops.nix header).
  environment.systemPackages = [
    pkgs.sops
    pkgs.age
    pkgs.openrgb-with-all-plugins # RGB, above
  ];

  # networking.hostName comes from mkHost (flake.nix).

  system.stateVersion = "24.11";
}
