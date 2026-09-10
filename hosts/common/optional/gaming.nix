{ config, pkgs, ... }:
{
  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = false;
      gamescopeSession.enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };
    gamemode = {
      enable = true;
      enableRenice = true;
      settings.general = {
        renice = 10;
        # gamemode balances the CPU governor against integrated-GPU load by
        # sampling /sys/class/powercap/intel-rapl/.../energy_uj, which is
        # root-only on current kernels (the PLATYPUS side-channel mitigation),
        # so the read just logs an error every time a game starts. Disable the
        # heuristic. 10000 (not the -1 the man page suggests) is the value that
        # actually does it: gamemode-context.c:330 gates the whole probe on
        # `threshold < 10000`, and -1 leaves the probe running while making the
        # later `ratio > threshold` test at :398 always true — which on a host
        # where RAPL *is* readable would hold the governor at igpu_desiredgov
        # (powersave) for the entire game.
        igpu_power_threshold = 10000;
        # inhibit_screensaver is not set: 1 is already gamemode's default.
      };
    };
    gamescope = {
      enable = true;
      # home-desktop's gamescopeSession passes --rt, which needs CAP_SYS_NICE on
      # the binary — without it gamescope warns and silently runs at normal
      # priority. NOTE: setcap binaries ignore LD_PRELOAD, which matters if
      # gamemode or MangoHud are ever preloaded into the session rather than
      # into Steam. It also drops the gamescope package from systemPackages
      # entirely (gamescope itself returns via /run/wrappers/bin, gamescopectl
      # does not) — hence the gamescopectl link below.
      capSysNice = true;
    };
  };

  environment.systemPackages = with pkgs; [
    # Big Picture's "Switch to Desktop" calls SteamOS's steamos-session-select,
    # which doesn't exist on NixOS — the button silently does nothing inside the
    # SDDM "Steam" (gamescope) session. Shim it to shut Steam down cleanly, which
    # ends the gamescope session and returns to the SDDM greeter, where the
    # desktop (Hyprland) session can be picked.
    (writeShellScriptBin "steamos-session-select" ''
      steam -shutdown
    '')
    # capSysNice above ships gamescope as a bare setcap wrapper, taking
    # gamescopectl (the runtime control socket client) with it. Link just that
    # one binary back onto PATH — linking the whole package would also put an
    # uncapped `gamescope` in /run/current-system/sw/bin, shadowing the wrapper
    # anywhere /run/wrappers/bin isn't searched first.
    (runCommand "gamescopectl" { } ''
      mkdir -p $out/bin
      ln -s ${gamescope}/bin/gamescopectl $out/bin/gamescopectl
    '')
    mangohud
    linuxConsoleTools
    protonup-qt
    protontricks
    heroic
    lutris
    itch
    goverlay
    vkbasalt
    vulkan-tools
    vulkan-validation-layers
    vulkan-loader
    glmark2
  ];

  boot.extraModulePackages = [ config.boot.kernelPackages.xpadneo ];
  hardware.graphics.enable32Bit = true;
  services.udev.packages = [ pkgs.steam ];

  boot.kernel.sysctl = {
    "vm.max_map_count" = 2147483642;
  };
}
