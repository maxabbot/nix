# modules/home/wm/dms-plugins.nix — DMS plugins, pinned and declared.
#
# Not a module: a plain function consumed by shell-switcher.nix (like
# outputs.nix), returning what to deploy, what to enable and which ids to put
# on the bar.
#
# Upstream's way is `dms plugins install`, an imperative git clone into
# ~/.config/DankMaterialShell/plugins/. Instead each plugin is a store path
# symlinked into that directory, so they're pinned by flake.lock and follow the
# host: a plugin for a service the host doesn't run isn't installed there.
# Plugins installed by hand still work alongside — the directory itself stays
# writable.
#
# All come from the registry's own Nix package set (dms-plugin-registry
# flake input, nix/default.nix — pinned revs and hashes), so `nix flake update
# dms-plugin-registry` bumps them together. Most AvengeMedia plugins need
# requires_dms >= 1.6 (I18n.trFor), which is why dms-shell comes from unstable
# (overlays/default.nix).
#
# Considered and left out:
#   • displaySettings — toggles outputs via `hyprctl eval hl.monitor`, and an
#     eval-disabled output only reliably comes back with `hyprctl reload`
#   • displayProfile — drives DMS's output profiles, which write hyprland.conf
#     (this config has hyprland.lua; see docs/SHELLS.md)
#   • ddcBrightness — DMS's DisplayService already does DDC/CI
#   • hyprlandSubmap — hyprland.lua defines no submaps
#   • keybindingCheatSheet — parses hyprland.conf; DMS has `dms keybinds`
#   • dockerManager — tried, dropped from the bar by choice
#   • nvidiaGpuMonitor — tried; GPU usage and temperature now come from the
#     system monitor pill (config/dms/BarSystemMonitor.qml)
#   • screenRecorder — quickCapture records as well
#   • dmsScreenshot — tried; a front end for `dms screenshot` with no editor,
#     replaced by quickCapture
{
  lib,
  pkgs,
  inputs,
  osConfig,
  isLaptop,
}:
let
  registry = import "${inputs.dms-plugin-registry}/nix/default.nix" { inherit pkgs; };

  # Bar pill icon: phonelink (phone + laptop) instead of a bare smartphone —
  # it reads as "phone linked to this machine" and pairs with the plugin's own
  # offline icon, phonelink_off.
  kdeConnect = pkgs.runCommand "dms-plugin-dankKDEConnect" { } ''
    cp -r ${registry.dankKDEConnect} $out
    chmod -R u+w $out
    substituteInPlace $out/DankKDEConnect.qml \
      --replace-fail 'root.selectedDevice.isReachable ? "smartphone" : "phonelink_off"' \
                     'root.selectedDevice.isReachable ? "phonelink" : "phonelink_off"'
  '';

  # The Claude Code logo (its pixel mascot) at the front of the usage pill;
  # upstream has only the two rings. Simple Icons' SVG, pinned by version and
  # hash, filled with its brand orange at build time. It replaces the ✳ in the
  # no-data text too. The horizontal pill is reduced to logo + the two rings
  # (their percentages are in the tooltip/popout) and tightened: less outer
  # padding (spacingM → spacingS), a smaller gap between items (spacingS →
  # spacingXS).
  claudeCodeLogo = pkgs.fetchurl {
    url = "https://cdn.jsdelivr.net/npm/simple-icons@16.32.0/icons/claudecode.svg";
    hash = "sha256-92kb7a5tceOeQUNvOeRTQwwe4h9jBaWWmExwpXhqu9o=";
  };
  claudeUsage = pkgs.runCommand "dms-plugin-claudeUsage" { } ''
    cp -r ${registry.claudeUsage} $out
    chmod -R u+w $out
    sed 's|<svg |<svg fill="#D97757" |' ${claudeCodeLogo} > $out/claude-code.svg
    substituteInPlace $out/ClaudeUsageWidget.qml \
      --replace-fail 'text: "✳ --"' 'text: "--"' \
      --replace-fail 'implicitWidth: row.implicitWidth + Theme.spacingM * 2' \
                     'implicitWidth: row.implicitWidth + Theme.spacingS * 2' \
      --replace-fail 'id: row
                    anchors.centerIn: parent
                    spacing: Theme.spacingS' 'id: row
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS' \
      --replace-fail '                        StyledText {
                                text: modelData.pct + "%"
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                                anchors.verticalCenter: parent.verticalCenter
                            }
    ' "" \
      --replace-fail '
                    StyledText {
                        visible: !root.hasData
    ' '
                    Image {
                        source: Qt.resolvedUrl("claude-code.svg")
                        readonly property int logoSize: Math.max(14, Math.min(pill.height - 7, 20))
                        sourceSize: Qt.size(logoSize * 2, logoSize * 2)
                        Layout.preferredWidth: logoSize
                        Layout.preferredHeight: logoSize
                        Layout.alignment: Qt.AlignVCenter
                        smooth: true
                    }

                    StyledText {
                        visible: !root.hasData
    '
  '';

  # Its Lua branch passes the window as a bare "address:0x…" string, which
  # Hyprland accepts and ignores; targets have to go through hl.get_window().
  # Same fix as the luaDispatch rewrites in shell-switcher.nix.
  hyprWindows = pkgs.runCommand "dms-plugin-dankHyprlandWindows" { } ''
    cp -r ${registry.dankHyprlandWindows} $out
    chmod -R u+w $out
    substituteInPlace $out/DankHyprlandWindows.qml \
      --replace-fail 'hl.dsp.focus({ window = "''${selector}" })' \
                     'hl.dsp.focus({ window = hl.get_window("''${selector}") })' \
      --replace-fail 'hl.dsp.window.close({window = "''${selector}"})' \
                     'hl.dsp.window.close({ window = hl.get_window("''${selector}") })'
  '';

  # Nix Monitor reads its commands from config.json inside its own directory
  # (hardcoded to plugins/NixMonitor/), so the file ships with the plugin.
  # Rebuild and GC mirror NixPanel: `nh os switch`, and `nh clean user` —
  # system generations are pruned by the weekly nh clean timer, not from the
  # bar. The store size sums narSize over every valid path (~7s, every 5 min):
  # du over /nix/store takes minutes, and df reports the whole root filesystem
  # (1464G against a ~200G store here).
  nixMonitorConfig = pkgs.writeText "nix-monitor-config.json" (
    builtins.toJSON {
      generationsCommand = [
        "sh"
        "-c"
        "ls -d /nix/var/nix/profiles/system-*-link | wc -l"
      ];
      # Its parser wants a number followed by G.
      storeSizeCommand = [
        "sh"
        "-c"
        "nix path-info --all --json 2>/dev/null | ${lib.getExe pkgs.jq} -r '[.[].narSize] | add / 1073741824 | floor | \"\\(.)G\"'"
      ];
      rebuildCommand = [
        "sh"
        "-c"
        "nh os switch /etc/nixos 2>&1"
      ];
      gcCommand = [
        "sh"
        "-c"
        "nh clean user --keep 3 --keep-since 3d 2>&1"
      ];
      # Compared against the channel this flake actually tracks.
      nixpkgsChannel = "nixos-${lib.versions.majorMinor lib.version}";
      updateInterval = 300;
    }
  );
  # Pill icons: the NixOS snowflake (Nerd Font, which DMS already loads
  # app-wide for StyledText) instead of a generic box, and a status icon
  # instead of a bare check — check_circle up to date, update behind, help
  # when it can't compare. Colours are upstream's.
  nixMonitor = pkgs.runCommand "dms-plugin-nixMonitor" { } ''
    cp -r ${registry.nixMonitor} $out
    chmod -R u+w $out
    cp ${nixMonitorConfig} $out/config.json
    substituteInPlace $out/NixMonitor.qml \
      --replace-fail 'DankIcon {
                    name: "inventory_2"
                    size: root.iconSize
    ' 'Text {
                    text: "\uf313" // nf-linux-nixos
                    font.family: "FiraCode Nerd Font"
                    font.pixelSize: root.iconSize
    ' \
      --replace-fail 'name: "check"' \
                     'name: root.canCompareVersions ? (root.isUpToDate ? "check_circle" : "update") : "help"'
  '';

  # Print opens quickCapture's bar menu as a floating, centred window, with no
  # bar pill: config/dms/QuickCapturePicker.qml hosts the menu, the daemon gets
  # an instance, and `dms ipc call quickCapture showPicker` toggles it
  # (config/hypr-scripts/shell-ipc.sh).
  quickCapture = pkgs.runCommand "dms-plugin-quickCapture" { } ''
    cp -r ${registry.quickCapture} $out
    chmod -R u+w $out
    cp ${../../../config/dms/QuickCapturePicker.qml} $out/QuickCapturePicker.qml
    substituteInPlace $out/QuickCaptureDaemon.qml \
      --replace-fail '        function showHistory(): string {' \
                     '        function showPicker(): string {
            picker.show();
            return "SUCCESS";
        }

        function showHistory(): string {' \
      --replace-fail '    RecordingRegionBorder {' \
                     '    QuickCapturePicker {
        id: picker
        daemon: root
    }

    RecordingRegionBorder {'
  '';

  # dir: directory name under plugins/ (only NixMonitor's matters — see above).
  # Launcher plugins (nixPackageRunner, dankHyprlandWindows) add a launcher
  # provider and have no bar pill.
  plugins = [
    {
      id = "nixMonitor";
      dir = "NixMonitor";
      src = nixMonitor;
    }
    {
      id = "nixPackageRunner";
      src = registry.nixPackageRunner;
    }
    {
      id = "dankKDEConnect";
      src = kdeConnect;
    }
    {
      id = "dankHyprlandWindows";
      src = hyprWindows;
    }
    {
      # Talks only to api.anthropic.com, with Claude Code's own OAuth token.
      id = "claudeUsage";
      src = claudeUsage;
    }
    {
      # Screenshots with an annotation editor, OCR, QR, scrolling capture and
      # screen recording. No bar pill or Control Center tile: Print opens its
      # menu floating (above). Its tools are in home.packages
      # (shell-switcher.nix).
      id = "quickCapture";
      src = quickCapture;
    }
  ]
  ++ lib.optional osConfig.services.tailscale.enable {
    id = "dankscale";
    src = registry.dankscale;
  }
  # Replaces the built-in battery pill: same icon + percent, but its popout
  # (and Control Center tile) adds UPower's charge history, health/drain stats
  # and power profiles. The profile buttons need power-profiles-daemon, so on
  # work-laptop they do nothing.
  ++ lib.optional isLaptop {
    id = "batteryPlus";
    src = registry.batteryPlus;
  };

  has = id: lib.any (p: p.id == id) plugins;
in
{
  configFiles = lib.listToAttrs (
    map (p: lib.nameValuePair "DankMaterialShell/plugins/${p.dir or p.id}" { source = p.src; }) plugins
  );

  # Merged into plugin_settings.json, which DMS owns like settings.json.
  settings =
    lib.genAttrs (map (p: p.id) plugins) (_: {
      enabled = true;
    })
    // {
      nixMonitor = {
        enabled = true;
        # Red above this. Upstream's 50G is below this store's steady state
        # (~200G), which kept the pill permanently red.
        gcThresholdGB = 250;
        # The pill is just the snowflake: generations, store size and the
        # nixpkgs-behind check stay in its popout.
        showGenerations = false;
        showStoreSize = false;
        checkUpdates = false;
      };
    };

  # Changes whenever any plugin's store path does. Quickshell's QML disk cache
  # keys on the file's URL and mtime, and both stay the same across a rebuild
  # (same plugins/<id>/ path, store mtime 1970), so without clearing it DMS
  # keeps running the previous version of an edited plugin.
  stamp = builtins.hashString "sha256" (
    builtins.unsafeDiscardStringContext (lib.concatMapStringsSep "\n" (p: "${p.src}") plugins)
  );

  # [ id ] when this host has the plugin, else [ ] — for the bar lists in
  # shell-switcher.nix.
  barWidget = id: lib.optional (has id) id;
}
