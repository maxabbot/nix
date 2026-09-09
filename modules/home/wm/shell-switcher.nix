# modules/home/wm/shell-switcher.nix — swap between three desktop shells.
#
# Installs Noctalia and DMS (DankMaterialShell) alongside this config's own
# Quickshell panels, and gives each one a systemd user unit.
#
# The units are mutually exclusive via Conflicts=: every one of these shells
# registers org.freedesktop.Notifications, so two running at once means one of
# them silently loses its notification daemon (and both draw a bar). Letting
# systemd enforce that — rather than pkill in the switcher script — makes the
# swap a single transaction: starting one unit stops the incumbent first.
#
# Driven by config/hypr-scripts/shell-switch.sh, bound to SUPER+ALT+1..3 and
# SUPER+ALT+S in config/hypr/hyprland.lua. The choice is recorded under
# $XDG_STATE_HOME/hypr/active-shell and re-applied at login by
# shell-restore.service.
#
# Both third-party shells are themed from config/stylix/palette.nix like every
# other app here, via their own custom-scheme mechanisms (see "Theming" below),
# and Noctalia's built-in wallpaper is switched off so awww stays the single
# wallpaper owner.
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.custom.hm;

  renderTheme = import ../../../config/stylix/palette-subst.nix { inherit lib; };

  scriptsDir = "${config.home.homeDirectory}/.config/hypr/scripts";
  # Deployed 0444 (see hyprland.nix), so invoke through bash rather than
  # exec'ing the script directly — a direct exec dies with 126.
  switch = "${pkgs.bash}/bin/bash ${scriptsDir}/shell-switch.sh";

  # ── Lua dispatch fixups ─────────────────────────────────────────────────────
  # Both third-party shells hardcode classic Hyprland dispatcher strings, which
  # this config's Lua parser evaluates as Lua and rejects: `dispatch
  # "workspace 3"` dies with `')' expected near '3'`. Every workspace click,
  # overview drag and window focus is a silent no-op without this. Exactly the
  # breakage waybar needed pkgs/waybar/hyprland-lua-dispatch.patch for.
  #
  # substituteInPlace on the installed QML rather than a .patch file: it is
  # plain text at a stable path, and --replace-fail turns a version bump that
  # reworded a call site into a BUILD failure rather than a silent return to
  # dead clicks.
  #
  # Window targets go through hl.get_window(): passing the address as a bare
  # string is accepted but does nothing (see the hyprland-lua-dispatch notes).
  luaDispatch =
    pkg: subs:
    pkg.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + lib.concatMapStrings (s: ''
        substituteInPlace "$out/${s.file}" \
          --replace-fail ${lib.escapeShellArg s.from} ${lib.escapeShellArg s.to}
      '') subs;
    });

  noctalia-shell = luaDispatch pkgs.noctalia-shell (
    let
      f = "share/noctalia-shell/Services/Compositor/HyprlandService.qml";
    in
    [
      {
        file = f;
        from = "Hyprland.dispatch(`workspace \${workspace.name}`);";
        to = "Hyprland.dispatch(`hl.dsp.focus({ workspace = \"\${workspace.name}\" })`);";
      }
      {
        file = f;
        from = "Hyprland.dispatch(`workspace \${workspace.idx}`);";
        to = "Hyprland.dispatch(`hl.dsp.focus({ workspace = \${workspace.idx} })`);";
      }
      {
        file = f;
        from = "Hyprland.dispatch(`focuswindow address:0x\${windowId}`);";
        to = "Hyprland.dispatch(`hl.dsp.focus({ window = hl.get_window(\"address:0x\${windowId}\") })`);";
      }
      {
        file = f;
        from = "Hyprland.dispatch(`alterzorder top,address:0x\${windowId}`);";
        to = "Hyprland.dispatch(`hl.dsp.window.bring_to_top({ window = hl.get_window(\"address:0x\${windowId}\") })`);";
      }
      {
        # Upstream names the function closeWindow but dispatches killwindow;
        # hl.dsp.window.kill preserves that, not window.close.
        file = f;
        from = "Hyprland.dispatch(`killwindow address:0x\${window.id}`);";
        to = "Hyprland.dispatch(`hl.dsp.window.kill({ window = hl.get_window(\"address:0x\${window.id}\") })`);";
      }
    ]
  );

  dms-shell = luaDispatch pkgs.dms-shell (
    let
      bar = "share/quickshell/dms/Modules/DankBar/DankBarContent.qml";
      sw = "share/quickshell/dms/Modules/DankBar/Widgets/WorkspaceSwitcher.qml";
      ov = "share/quickshell/dms/Modules/WorkspaceOverlays/OverviewWidget.qml";
      hov = "share/quickshell/dms/Modules/WorkspaceOverlays/HyprlandOverview.qml";
    in
    [
      {
        file = bar;
        from = "Hyprland.dispatch(`workspace \${realWorkspaces[nextIndex].id}`);";
        to = "Hyprland.dispatch(`hl.dsp.focus({ workspace = \${realWorkspaces[nextIndex].id} })`);";
      }
      {
        file = sw;
        from = "Hyprland.dispatch(`workspace \${data.id}`);";
        to = "Hyprland.dispatch(`hl.dsp.focus({ workspace = \${data.id} })`);";
      }
      {
        file = sw;
        from = "Hyprland.dispatch(`workspace \${realWorkspaces[nextIndex].id}`);";
        to = "Hyprland.dispatch(`hl.dsp.focus({ workspace = \${realWorkspaces[nextIndex].id} })`);";
      }
      {
        file = sw;
        from = "Hyprland.dispatch(`workspace \${modelData.id}`);";
        to = "Hyprland.dispatch(`hl.dsp.focus({ workspace = \${modelData.id} })`);";
      }
      {
        # Two identical call sites in this file; both are rewritten.
        file = sw;
        from = "Hyprland.dispatch(`focuswindow address:\${winId}`);";
        to = "Hyprland.dispatch(`hl.dsp.focus({ window = hl.get_window(\"address:\${winId}\") })`);";
      }
      {
        file = ov;
        from = "Hyprland.dispatch(`workspace \${workspaceValue}`)";
        to = "Hyprland.dispatch(`hl.dsp.focus({ workspace = \${workspaceValue} })`)";
      }
      {
        # Drag a window onto another workspace in the overview. "silent" =
        # don't follow it, hence follow = false.
        file = ov;
        from = "Hyprland.dispatch(`movetoworkspacesilent \${targetWorkspace},address:\${windowData?.address}`)";
        to = "Hyprland.dispatch(`hl.dsp.window.move({ window = hl.get_window(\"address:\${windowData?.address}\"), workspace = \${targetWorkspace}, follow = false })`)";
      }
      {
        file = ov;
        from = "Hyprland.dispatch(`focuswindow address:\${windowData.address}`)";
        to = "Hyprland.dispatch(`hl.dsp.focus({ window = hl.get_window(\"address:\${windowData.address}\") })`)";
      }
      {
        file = ov;
        from = "Hyprland.dispatch(`closewindow address:\${windowData.address}`)";
        to = "Hyprland.dispatch(`hl.dsp.window.close({ window = hl.get_window(\"address:\${windowData.address}\") })`)";
      }
      {
        file = hov;
        from = ''Hyprland.dispatch("workspace " + targetId)'';
        to = ''Hyprland.dispatch("hl.dsp.focus({ workspace = " + targetId + " })")'';
      }
      {
        # Power menu's log-out. Correct by the API's shape, but the only
        # substitution here not verified by running it — testing costs the
        # session.
        file = "share/quickshell/dms/Services/SessionService.qml";
        from = ''Hyprland.dispatch("exit");'';
        to = ''Hyprland.dispatch("hl.dsp.exit()");'';
      }
      # Deliberately NOT rewritten: `dpms off` / `dpms on` in
      # Services/CompositorService.qml. hl.dsp.dpms ignores its state argument
      # and just toggles, so a literal translation would make DMS's idle
      # handling worse than the current no-op — an absolute "on" needs the
      # per-monitor dpmsStatus dance in config/hypr-scripts/wake-monitors.sh.
      # Hypridle owns screen blanking here anyway.
    ]
  );

  shells = {
    own = {
      description = "Desktop shell: this config's Quickshell panels + Waybar";
      exec = "${pkgs.quickshell}/bin/quickshell -p ${scriptsDir}/quickshell/Shell.qml";
      # Waybar is this shell's bar; it is PartOf shell-own.service (see
      # waybar.nix) so it comes and goes with it.
      wants = [ "waybar.service" ];
    };
    noctalia = {
      description = "Desktop shell: Noctalia";
      exec = "${noctalia-shell}/bin/noctalia-shell";
      wants = [ ];
    };
    dms = {
      description = "Desktop shell: DankMaterialShell";
      # --session is upstream's own systemd invocation: stays in the
      # foreground and expects to be session-managed.
      exec = "${dms-shell}/bin/dms run --session";
      wants = [ ];
    };
  };

  unitName = name: "shell-${name}.service";
  allUnits = map unitName (lib.attrNames shells);

  mkShellUnit = name: shell: {
    Unit = {
      Description = shell.description;
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      Requisite = [ "graphical-session.target" ];
      Conflicts = lib.filter (u: u != unitName name) allUnits;
      Wants = shell.wants;
    };
    Service = {
      Type = "simple";
      ExecStart = shell.exec;
      # A stop triggered by Conflicts= is a clean SIGTERM, not a failure, so
      # this does not fight the switcher — it only covers a shell crashing.
      Restart = "on-failure";
      RestartSec = 2;
      Slice = "session.slice";
    };
    # Deliberately no Install.WantedBy: nothing may autostart a shell, or the
    # login would race all three. shell-restore.service picks exactly one.
  };
in
{
  config = lib.mkIf (cfg.compositor == "hyprland") {
    home.packages = [
      noctalia-shell
      dms-shell
    ];

    # ── Theming ───────────────────────────────────────────────────────────────
    # Both shells read a user-supplied scheme file that they never write back
    # to, so unlike their settings.json these can be plain store symlinks
    # rendered from palette.nix.
    #
    # Noctalia scans its scheme dir with `find -mindepth 2`, so the JSON has to
    # sit in a subdirectory of its own — colorschemes/<name>/<name>.json — and
    # the scheme's display name is that basename.
    xdg.configFile."noctalia/colorschemes/Gruvbox-Material/Gruvbox-Material.json".text =
      renderTheme ../../../config/noctalia/Gruvbox-Material.json;
    xdg.configFile."DankMaterialShell/gruvbox-material.json".text =
      renderTheme ../../../config/dms/gruvbox-material.json;

    # Pointing each shell AT its scheme has to be done differently: settings.json
    # is owned and rewritten by the shell itself, so it can't be a store symlink
    # (Noctalia would lose every setting it tries to save). Merge just the keys
    # we care about instead, leaving everything else as the user left it, and
    # create a partial file when the shell has never run — both use Quickshell's
    # Store, which loads JSON over its property defaults, so partial is fine.
    home.activation.shellThemeSettings =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        merge_settings() {
          local file="$1" filter="$2" dir
          dir="$(dirname "$file")"
          $DRY_RUN_CMD mkdir -p "$dir"
          if [ -s "$file" ]; then
            $DRY_RUN_CMD ${pkgs.jq}/bin/jq "$filter" "$file" > "$file.hm-tmp"               && $DRY_RUN_CMD mv "$file.hm-tmp" "$file"
          else
            $DRY_RUN_CMD ${pkgs.jq}/bin/jq -n "$filter" > "$file"
          fi
        }

        # Noctalia: use our scheme, stop deriving colours from the wallpaper,
        # and stop drawing a wallpaper at all — awww already owns that layer,
        # and Noctalia stacks its own on top rather than replacing it.
        merge_settings "${config.xdg.configHome}/noctalia/settings.json"           '.colorSchemes.predefinedScheme = "Gruvbox-Material"
           | .colorSchemes.useWallpaperColors = false
           | .wallpaper.enabled = false'

        # DMS: currentThemeName drives Theme.switchTheme(), and the literal
        # "custom" is what makes it read customThemeFile.
        merge_settings "${config.xdg.configHome}/DankMaterialShell/settings.json"           '.currentThemeName = "custom"
           | .currentThemeCategory = "custom"
           | .customThemeFile = "${config.xdg.configHome}/DankMaterialShell/gruvbox-material.json"'
      '';

    systemd.user.services =
      lib.mapAttrs' (name: shell: {
        name = "shell-${name}";
        value = mkShellUnit name shell;
      }) shells
      // {
        # Re-applies the recorded choice at login, so a switch survives logout.
        # The script uses `systemctl --user --no-block start`: a blocking start
        # from inside a unit this same manager is running would deadlock.
        shell-restore = {
          Unit = {
            Description = "Start the desktop shell recorded by shell-switch.sh";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${switch} restore";
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      };
  };
}
