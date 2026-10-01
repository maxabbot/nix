# modules/home/wm/hyprland.nix — Hyprland window manager configuration.
{
  lib,
  config,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.custom.hm;
  renderTheme = import ../../../config/stylix/palette-subst.nix { inherit lib; };

  # Hold the resume path until the GPU is back, then wake the outputs.
  #
  # logind emits PrepareForSleep(false) as soon as systemd-suspend.service
  # finishes, and nvidia-resume.service — which restores the preserved VRAM
  # allocations — is only ordered After= that same unit, so it has not even
  # started when hypridle acts on the signal. Waking and re-rendering inside
  # that window can wedge a hyprlock that survived the suspend: its resource
  # gatherer stops completing, it commits no further frames, and
  # ext-session-lock then obliges the compositor to paint black. Screens lit,
  # nothing on them, no crash to show for it, and after_sleep_cmd's pidof guard
  # keeps the wedged instance rather than replacing it (seen 2026-09-03 16:25;
  # the identical resume 70 minutes earlier was fine, hence a race).
  #
  # Two phases, because the job is still queued when the signal lands: up to 1 s
  # for it to reach "activating", then up to 10 s for it to leave. Both are
  # capped so a stuck unit can never strand the session on a black screen.
  #
  # `systemctl is-active` cannot express this — a Type=oneshot unit stays
  # "activating" for the whole of its ExecStart and never becomes "active", so
  # is-active returns non-zero throughout and the wait would be a no-op.
  # LoadState gates the whole thing at runtime instead of in Nix, so the
  # non-NVIDIA hosts skip it in one systemctl call and nothing here has to
  # duplicate the conditions under which NixOS emits the unit.
  waitForNvidiaResume =
    let
      state = "\"$(systemctl show -p ActiveState --value nvidia-resume.service)\"";
    in
    "if [ \"$(systemctl show -p LoadState --value nvidia-resume.service)\" = loaded ]; then "
    + "i=0; while [ $i -lt 10 ] && [ ${state} != activating ]; do i=$((i+1)); sleep 0.1; done; "
    + "i=0; while [ $i -lt 100 ] && [ ${state} = activating ]; do i=$((i+1)); sleep 0.1; done; "
    + "fi; ";

  # Snapshot the session across a resume into a file that survives the reboot.
  # setsid + backgrounded: it samples for 30s, and the wake must not wait on it.
  # stderr is left attached so hypridle journals it if the probe itself breaks.
  resumeProbe = "setsid bash ~/.config/hypr/scripts/resume-probe.sh </dev/null >/dev/null & ";

  # Blank both outputs before the machine goes down — an experiment against the
  # lit-but-black resume (see the semsurf notes; instrumentation in
  # resume-probe.sh). Every probe-captured failure so far was a *manual* suspend
  # with the screens still lit, and the one clean resume was the 900s idle path,
  # where idle-off had already blanked them 30s earlier. The theory: a DPMS-off
  # output has its CRTC torn down, so nothing is scanning out and no explicit-sync
  # fence is mid-wait when the GPU sleeps — and the wake has to build a full
  # modeset from scratch rather than restore state that did not survive.
  #
  # hold-off, not off: it disarms misc.{mouse_move,key_press}_enables_dpms first,
  # so a stray input event in the second between blanking and suspend entry can't
  # light the screens back up and undo the whole point. dpms.sh on re-arms input
  # wake on the far side once nothing is left blanked.
  #
  # The sleep gives hyprlock time to come up first: it renders on frame callbacks,
  # which a blanked output stops delivering, and a half-initialised lock screen on
  # resume would be a worse bug than the one being chased. On the idle path this
  # is a no-op anyway — idle-off blanked them at 330s and every dpms.sh verb only
  # toggles what actually differs.
  blankBeforeSleep = "loginctl lock-session; sleep 1; bash ~/.config/hypr/scripts/dpms.sh hold-off";

  # Skip an idle action while DMS's caffeine is on. DMS inhibits idle through a
  # Wayland idle-inhibitor on its bar, and that inhibitor goes missing after a
  # resume. DMS rebuilds its bar surfaces twice on wake, and hypridle locked 5
  # min after both resumes on 2026-09-28 with `dms ipc inhibit status` still
  # reporting enabled. Asking DMS directly doesn't depend on the compositor
  # seeing the inhibitor. `timeout` so a wedged IPC call can't hang hypridle's
  # action; with DMS down (gaming mode) the call fails and the action runs.
  unlessCaffeine =
    cmd: "timeout 2 dms ipc inhibit status 2>/dev/null | grep -q 'is enabled' || ${cmd}";

  # Parse a hyprlang monitor string "NAME,WxH@Hz,XxY,SCALE[,transform,N]"
  # into a Lua hl.monitor({}) call.
  monitorToLua =
    s:
    let
      parts = builtins.map lib.strings.trim (lib.splitString "," s);
      output = builtins.elemAt parts 0;
      mode = builtins.elemAt parts 1;
      position = builtins.elemAt parts 2;
      scale = builtins.elemAt parts 3;
      hasTransform = builtins.length parts >= 6;
      transformVal = if hasTransform then builtins.elemAt parts 5 else "";
    in
    ''hl.monitor({ output = "${output}", mode = "${mode}", position = "${position}", scale = ${scale}${lib.optionalString hasTransform ", transform = ${transformVal}"} })'';

  # Workspaces are intentionally NOT pinned to monitors: with no
  # hl.workspace_rule() monitor binds, all 1–9 are a shared dynamic pool,
  # freely movable between monitors. The *initial* placement (ws1→primary,
  # ws2→secondary) is instead set once at startup in
  # config/hypr/hyprland.lua's autostart, using the connector names exported
  # by monitors.lua below.
  secName =
    if cfg.monitors.secondary != null then
      lib.head (lib.splitString "," cfg.monitors.secondary)
    else
      "";

  # The generated monitors.lua content
  monitorsLua = ''
    -- Auto-generated by Nix from modules/home/wm/hyprland.nix
    -- Do not edit manually.

    ${lib.optionalString (cfg.monitors.secondary != null) (monitorToLua cfg.monitors.secondary)}
    ${lib.optionalString (cfg.monitors.primary != null) (monitorToLua cfg.monitors.primary)}
    ${lib.optionalString (
      cfg.monitors.primary == null
    ) ''hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })''}

    -- Consumed by hyprland.lua: cursor.default_monitor (spawn cursor on
    -- primary) and the startup workspace placement (primary/secondary).
    -- Absent monitors export "" so callers can skip them.
    return {
      primary = "${cfg.monitors.primaryName}",
      secondary = "${secName}",
    }
  '';

  # The cheat sheet is one shared document; only the subtitle is per-host.
  shortcutsMd = builtins.replaceStrings [ "@host@" ] [ osConfig.networking.hostName ] (
    builtins.readFile ../../../docs/SHORTCUTS.md
  );

  # The generated env.lua content — per-host env vars plus app choices.
  # Returns a table that hyprland.lua's keybinds consume via require("env").
  envLua = ''
    -- Auto-generated by Nix from modules/home/wm/hyprland.nix
    -- Do not edit manually.
    hl.env("TERMINAL", "${cfg.terminal}")
    hl.env("BROWSER",  "${cfg.browser}")
    ${lib.optionalString cfg.nvidia ''
      hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
      hl.env("LIBVA_DRIVER_NAME",         "nvidia")
      hl.env("__GL_GSYNC_ALLOWED",        "1")
      hl.env("__GL_VRR_ALLOWED",          "1")''}

    return {
      terminal = "${cfg.terminal}",
      browser  = "${cfg.browser}",
    }
  '';

  # The generated wallpaper.lua content — per-output awww invocations.
  # All outputs crop-fill the host wallpaper; a rotated/portrait secondary is
  # then overridden with a rendered SHORTCUTS.md cheat-sheet
  # (see config/hypr-scripts/shortcuts-wallpaper.sh).
  wallpaperLua =
    let
      transition = "--transition-type wipe --transition-fps 60";
      # awww-daemon is exec'd just before this file is required, and exec_cmd
      # doesn't wait for it: an `awww img` that lands before the daemon's socket
      # is up fails, and the daemon then restores its per-output cache instead.
      # That's invisible while the cache already holds the configured image, but
      # a changed wallpaper option never took — the old one kept coming back.
      # exec_cmd runs through `sh -c`, so the wait can be inline.
      waitDaemon = "until awww query >/dev/null 2>&1; do sleep 0.1; done; ";
      secName = lib.optionalString (cfg.monitors.secondary != null) (
        lib.head (lib.splitString "," cfg.monitors.secondary)
      );
      secRotated =
        cfg.monitors.secondary != null && builtins.length (lib.splitString "," cfg.monitors.secondary) >= 6;
    in
    ''
      -- Auto-generated by Nix from modules/home/wm/hyprland.nix
      -- Do not edit manually.
      hl.exec_cmd("${waitDaemon}awww img ~/.config/hypr/wallpaper.png --resize crop ${transition}")
    ''
    + lib.optionalString (secRotated && cfg.wallpaperPortrait == null) ''
      hl.exec_cmd("${waitDaemon}bash ~/.config/hypr/scripts/shortcuts-wallpaper.sh ${secName}")
    ''
    + lib.optionalString (secRotated && cfg.wallpaperPortrait != null) ''
      hl.exec_cmd("${waitDaemon}awww img ~/.config/hypr/wallpaper-portrait.png --outputs ${secName} --resize crop ${transition}")
    '';
in
{
  options.custom.hm = {
    compositor = lib.mkOption {
      type = lib.types.enum [
        "hyprland"
        "none"
      ];
      default = "none";
      description = "Which Wayland compositor to configure for this user.";
    };

    nvidia = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to set NVIDIA-specific Hyprland environment variables.";
    };

    terminal = lib.mkOption {
      type = lib.types.str;
      default = "kitty";
      description = "Terminal command — used by the Super+Return bind and exported as $TERMINAL.";
    };

    browser = lib.mkOption {
      type = lib.types.str;
      default = "zen-beta";
      description = "Browser command — used by the Super+B bind and exported as $BROWSER.";
    };

    wallpaper = lib.mkOption {
      type = lib.types.path;
      default = ../../../config/sddm/leaves-wall.png;
      description = "Desktop wallpaper image, deployed to ~/.config/hypr/wallpaper.png and set by awww.";
    };

    wallpaperPortrait = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Image for a rotated secondary monitor, deployed to ~/.config/hypr/wallpaper-portrait.png. When null the secondary shows the rendered SHORTCUTS.md cheat-sheet.";
    };

    monitors = {
      primary = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Primary monitor string, e.g. DP-3,2560x1440@165,2160x0,1";
      };
      primaryName = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Connector name of the primary monitor, e.g. DP-3. Used to pin workspaces.";
      };
      secondary = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Secondary monitor string, e.g. DP-2,3840x2160@60,0x0,1,transform,3";
      };
    };
  };

  config = lib.mkIf (cfg.compositor == "hyprland") {

    # hl.env in env.lua only reaches Hyprland and what it spawns. Under UWSM
    # the systemd user units (shell-dms.service among them) inherit the login
    # environment instead, and without $TERMINAL DMS's launcher runs
    # Terminal=true entries (spotify-player, yazi) in xterm — not installed,
    # so they fail silently.
    home.sessionVariables = {
      TERMINAL = cfg.terminal;
      BROWSER = cfg.browser;
    };

    xdg.configFile = {
      # ── Store-symlinked scripts (gaming-toggle, dpms, wallpaper, …) ─────────
      "hypr/scripts".source = ../../../config/hypr-scripts;
      # ── Per-host monitor + workspace config (generated by Nix) ──────────────
      "hypr/monitors.lua".text = monitorsLua;
      # ── Per-host environment variables (generated by Nix) ────────────────────
      "hypr/env.lua".text = envLua;
      # ── Per-host wallpaper command(s) (generated by Nix) ─────────────────────
      "hypr/wallpaper.lua".text = wallpaperLua;
      # ── Wallpaper — deployed to ~/.config/hypr/wallpaper.png, set by awww ─────
      "hypr/wallpaper.png".source = cfg.wallpaper;
      "hypr/wallpaper-portrait.png" = lib.mkIf (cfg.wallpaperPortrait != null) {
        source = cfg.wallpaperPortrait;
      };
      # ── Shortcuts cheat-sheet source + style (rendered onto the 2nd monitor) ─
      # @host@ is substituted so the subtitle names the machine the sheet is
      # actually deployed on, rather than whichever host it was written for.
      "hypr/shortcuts.md".text = shortcutsMd;
      "hypr/shortcuts.css".text = renderTheme ../../../config/hypr/shortcuts.css;
    };

    # ── Wallpaper directory ──────────────────────────────────────────────────
    # DMS's wallpaper picker defaults here, and it didn't exist, so the picker
    # listed nothing. Seeded with a real copy of the wallpaper rather than an HM
    # symlink, and only when the directory is first created, so deleting the
    # image later isn't undone by the next nixup.
    home.activation.wallpaperDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      dir="${config.home.homeDirectory}/Pictures/Wallpapers"
      if [ ! -d "$dir" ]; then
        $DRY_RUN_CMD mkdir -p "$dir"
        $DRY_RUN_CMD install -m 0644 ${cfg.wallpaper} "$dir/${baseNameOf cfg.wallpaper}"
      fi
    '';

    # ── Tray applets — systemd user services instead of sleep-raced exec-once ─
    # Both HM services bind to tray.target (declared by HM's wayland module).
    # nm-applet (SNI mode) re-registers once the DMS tray appears;
    # syncthingtray's default command already passes --wait.
    xsession.preferStatusNotifierItems = true; # nm-applet --indicator (SNI)

    # Polkit authentication agent — GUI privilege prompts (gparted, virt-manager,
    # flatpak system installs). polkit_gnome's binary lives in libexec (never on
    # PATH), so it must be referenced by store path; nothing else in the session
    # provides an agent — without one, auth prompts silently never appear.
    systemd.user.services.polkit-gnome-agent = {
      Unit = {
        Description = "polkit-gnome authentication agent";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # Solaar tray — Logitech Unifying/Bolt device manager (MX Ergo S). Only on
    # hosts importing hosts/common/optional/logitech.nix; elsewhere the mkIf
    # discards the definition unevaluated, so solaar stays out of their closure.
    #
    # It has to be resident, not launched on demand: Solaar re-applies its stored
    # per-device settings (button remaps, pointer speed, rules) each time a device
    # wakes or re-pairs, and does nothing at all while it isn't running. `-w hide`
    # starts it into the tray rather than popping the window open at every login,
    # so it needs tray.target the same way the applets below do.
    #
    # --restart-on-wake-up: this box suspends on the 900s hypridle timer, and
    # Solaar routinely loses the receiver across a resume — after which it stops
    # re-applying anything, silently. Upstream still labels the flag experimental;
    # if it turns out to restart in a loop, this is the first thing to drop.
    systemd.user.services.solaar = lib.mkIf osConfig.hardware.logitech.wireless.enableGraphical {
      Unit = {
        Description = "Solaar Logitech device manager (tray)";
        Requires = [ "tray.target" ];
        After = [
          "graphical-session.target"
          "tray.target"
        ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.solaar}/bin/solaar --window=hide --restart-on-wake-up";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # Solaar rule engine — see the file header for the diversion step each rule
    # needs and for what Wayland rules out. Only rules.yaml is declared: the
    # sibling config.yaml holds per-device state Solaar rewrites itself (DPI,
    # battery, which keys are diverted), so a read-only symlink there would just
    # fight the daemon. Declaring this file does mean Solaar's GUI rule editor
    # can't save over it — edit it here and rebuild instead.
    xdg.configFile."solaar/rules.yaml" = lib.mkIf osConfig.hardware.logitech.wireless.enableGraphical {
      source = ../../../config/solaar/rules.yaml;
    };

    services = {
      network-manager-applet.enable = true;
      syncthing.tray.enable = true;

      # ── Hypridle ────────────────────────────────────────────────────────────
      hypridle = {
        enable = true;
        settings = {
          general = {
            # pidof guard: don't spawn a second hyprlock if one is already up
            # (lock at 5min then loginctl lock-session at suspend = duplicate = crash).
            lock_cmd = "pidof hyprlock || hyprlock";
            before_sleep_cmd = blankBeforeSleep;
            # pidof guard here too: killing the live hyprlock on resume made
            # Hyprland flash its red "lockscreen died" fallback screen every wake.
            # dpms.sh, not `hyprctl dispatch dpms on` — dispatch args are Lua, so
            # the bare `on` is a parse error and the screens stay black.
            #
            # waitForNvidiaResume is the ordering fix — see the comment on it.
            #
            # resumeProbe runs first and detached, so it brackets the whole
            # window (the nvidia wait included) without delaying the wake by the
            # 30s it spends sampling. See the script header for why a resume
            # that comes back lit-but-blank currently leaves no evidence behind.
            after_sleep_cmd =
              resumeProbe
              + waitForNvidiaResume
              + "bash ~/.config/hypr/scripts/dpms.sh on; pidof hyprlock || hyprlock";
          };
          listener = [
            {
              timeout = 300;
              on-timeout = unlessCaffeine "loginctl lock-session";
            }
            # Blank the screens shortly after the lock rather than leaving them
            # lit until the 15-minute suspend. 30s of grace after hyprlock
            # appears, so the screen doesn't die out from under you mid-password.
            #
            # `idle-off`, not `off`: it no-ops while gaming mode owns the DPMS
            # state, and it leaves wake-on-input armed so a keypress lights them
            # back up. on-resume is the belt-and-braces path for the case where
            # something (a manual blank, gaming mode's exit) left that disarmed.
            {
              timeout = 330;
              on-timeout = unlessCaffeine "bash ~/.config/hypr/scripts/dpms.sh idle-off";
              on-resume = "bash ~/.config/hypr/scripts/dpms.sh idle-on";
            }
            {
              timeout = 900;
              on-timeout = unlessCaffeine "systemctl suspend";
            }
          ];
        };
      };
    };

    # ── Hyprland WM — configType "lua" makes HM write hyprland.lua; extraConfig
    # is appended to it. nixpkgs' hyprland is used (the default), which avoids
    # the flake source-tarball evaluation-time fetch issue.
    wayland.windowManager.hyprland = {
      enable = true;
      xwayland.enable = true;
      configType = "lua";
      extraConfig = renderTheme ../../../config/hypr/hyprland.lua;
      systemd.enable = false; # UWSM handles session/systemd integration
    };
  };
}
