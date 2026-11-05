# modules/home/wm/dms-plugins.nix — DMS plugins, pinned and declared.
#
# Not a module: a plain function consumed by dms.nix (like
# outputs.nix), returning what to deploy, what to enable and which ids to put
# on the bar.
#
# Upstream's way is `dms plugins install`, an imperative git clone into
# ~/.config/dms/plugins/. Instead each plugin is a store path
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
  lanMouse,
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

  # Tapping the Control Center tile's icon pauses/resumes Clight (the text still
  # opens the detail view — DMS's CompoundPill splits the two). Upstream wires
  # no ccWidgetToggled handler, so the icon did nothing and Pause was only in
  # the detail view.
  #
  # The tap reads Clight's live Suspended first instead of trusting the
  # plugin's cached state, which went stale in practice (taps kept sending
  # Pause(true)). That matters because Clight counts pauses: each Pause(true)
  # is one more hold, even when already paused, and it only resumes once every
  # hold is released — so a stale tap would leave it stuck paused.
  clight = pkgs.runCommand "dms-plugin-dankClight" { } ''
    cp -r ${registry.dankClight} $out
    chmod -R u+w $out
    substituteInPlace $out/DankClight.qml \
      --replace-fail 'import qs.Modules.Plugins' \
                     'import qs.Modules.Plugins
    import qs.Services' \
      --replace-fail 'ccWidgetIsActive: ClightService.available && !ClightService.suspended && !ClightService.inhibited' \
                     'ccWidgetIsActive: ClightService.available && !ClightService.suspended && !ClightService.inhibited
        onCcWidgetToggled: {
            if (!ClightService.available)
                return;
            DMSService.dbusGetProperty("session", ClightService.clightService, ClightService.clightPath, ClightService.clightInterface, "Suspended", response => {
                if (response.error)
                    return;
                const pause = !response.result?.value;
                ClightService.setPaused(pause);
                ClightService.suspended = pause;
            });
        }'
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
  #
  # The popout also gets an account switcher (config/dms/ClaudeAccounts.qml):
  # the logins saved with pkgs/claude-account, a tap swaps Claude Code to one
  # and refetches the usage, which follows the same credentials file.
  claudeUsage = pkgs.runCommand "dms-plugin-claudeUsage" { } ''
    cp -r ${registry.claudeUsage} $out
    chmod -R u+w $out
    sed 's|<svg |<svg fill="#D97757" |' ${claudeCodeLogo} > $out/claude-code.svg
    substitute ${../../../config/dms/ClaudeAccounts.qml} $out/ClaudeAccounts.qml \
      --replace-fail '@claudeAccount@' '${lib.getExe pkgs.claude-account}'
    substituteInPlace $out/ClaudeUsageWidget.qml \
      --replace-fail '    function minutesOld() { return data.minutesOld() }' \
                     '    function minutesOld() { return data.minutesOld() }
        function refreshUsage() { data.refresh() }' \
      --replace-fail 'popoutHeight: 220' 'popoutHeight: 330' \
      --replace-fail '                    color: mins > root.staleMinutes ? Theme.warning : Theme.surfaceTextMedium
                        font.pixelSize: Theme.fontSizeSmall
                    }' '                    color: mins > root.staleMinutes ? Theme.warning : Theme.surfaceTextMedium
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    ClaudeAccounts {
                        width: parent.width
                        onSwitched: root.refreshUsage()
                    }' \
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
                        readonly property int logoSize: Math.max(14, Math.min(root.widgetThickness - 7, 20))
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
  # Same fix as the luaDispatch rewrites in dms.nix.
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
  # Pill icons: the NixOS snowflake (JetBrainsMono Nerd Font, installed
  # system-wide by base.nix) instead of a generic box, and a status icon
  # instead of a bare check — check_circle up to date, update behind, help
  # when it can't compare. Colours are upstream's, except that DMS 2.0 dropped
  # Theme.onSecondary (the Rebuild button's text, left undefined); onPrimary
  # is the same dark-on-accent role.
  #
  # It lives in Quick Settings rather than the bar, which upstream has no tile
  # for: the tile shows generations and store size, highlights when the store
  # passes the GC threshold or nixpkgs is ahead, and opens upstream's own
  # popout (minus its close button) as the detail page.
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
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: root.iconSize
    ' \
      --replace-fail 'name: "check"' \
                     'name: root.canCompareVersions ? (root.isUpToDate ? "check_circle" : "update") : "help"' \
      --replace-fail 'textColor: Theme.onSecondary' 'textColor: Theme.onPrimary' \
      --replace-fail '    popoutWidth: 450' '    ccWidgetIcon: "ac_unit"
    ccWidgetPrimaryText: "Nix"
    ccWidgetSecondaryText: root.isLoading ? "Loading…" : root.generationCount + " gens · " + root.storeSize + (root.canCompareVersions && !root.isUpToDate ? " · update" : "")
    ccWidgetIsActive: root.storeSizeGB > root.gcThresholdGB || (root.canCompareVersions && !root.isUpToDate)
    ccWidgetIsToggle: false
    ccDetailHeight: 500
    ccDetailContent: Component {
        Rectangle {
            width: parent.width
            height: Math.min(parent.height, nixDetail.implicitHeight + Theme.spacingL * 2)
            radius: Theme.cornerRadius
            color: Theme.nestedSurface
            border.color: Theme.outlineMedium
            border.width: Theme.layerOutlineWidth
            clip: true

            Loader {
                id: nixDetail
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingL
                sourceComponent: root.popoutContent
                onLoaded: item.showCloseButton = false
            }
        }
    }

    popoutWidth: 450'
    ${lib.getExe pkgs.jq} '.capabilities += ["control-center"]' $out/plugin.json > plugin.json
    cp plugin.json $out/plugin.json
  '';

  # Left-clicking a menu row copies the capture straight to the clipboard
  # (upstream opens the editor); right-click opens the editor instead.

  # Print opens quickCapture's bar menu as a floating, centred window, with no
  # bar pill: config/dms/QuickCapturePicker.qml hosts the menu, the daemon gets
  # an instance, and `dms ipc call quickCapture showPicker` toggles it (the
  # Print bind in config/hypr/hyprland.lua).
  quickCapture = pkgs.runCommand "dms-plugin-quickCapture" { } ''
    cp -r ${registry.quickCapture} $out
    chmod -R u+w $out
    cp ${../../../config/dms/QuickCapturePicker.qml} $out/QuickCapturePicker.qml
    substituteInPlace $out/components/bar/CaptureMenuItem.qml \
      --replace-fail 'mouse.button === Qt.RightButton ? root.rightClickAction : "edit"' \
                     'mouse.button === Qt.RightButton ? "edit" : "copy"'
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

  # Dankscale sits in Quick Settings, not the bar (dms.nix), but upstream's
  # tile is only a connect toggle: its panel (devices, exit nodes, Taildrop,
  # accounts) was the bar pill's popout. The tile's chevron now opens that
  # popout as its detail page. The popout only holds Tailscale's detail
  # subscription while its bar popout is visible (parentPopout), which a
  # Quick Settings page never sets, so the page takes and drops it itself.
  dankscale = pkgs.runCommand "dms-plugin-dankscale" { } ''
    cp -r ${registry.dankscale} $out
    chmod -R u+w $out
    substituteInPlace $out/Tailscale.qml \
      --replace-fail '    onCcWidgetToggled: TailscaleService.toggleConnection()
' '    onCcWidgetToggled: TailscaleService.toggleConnection()
    ccDetailHeight: 480
    ccDetailContent: Component {
        Rectangle {
            width: parent.width
            height: Math.min(parent.height, tsDetail.implicitHeight + Theme.spacingL * 2)
            radius: Theme.cornerRadius
            color: Theme.nestedSurface
            border.color: Theme.outlineMedium
            border.width: Theme.layerOutlineWidth
            clip: true

            Component.onCompleted: TailscaleService.acquireDetails()
            Component.onDestruction: TailscaleService.releaseDetails()

            Loader {
                id: tsDetail
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingL
                sourceComponent: root.popoutContent
                onLoaded: item.showCloseButton = false
            }
        }
    }
'
  '';

  # Battery levels of peripherals the shell doesn't show: the MX Ergo S (via
  # Solaar's library), Bluetooth devices, headsets. Its pill hides itself when
  # no device reports a battery. The daemon runs its helper with a bare
  # `python3`; this one carries what the helper imports — Solaar's
  # logitech_receiver, dbus-python and pygobject (BlueZ/D-Bus), pyudev
  # (instant re-read on plug/dock). The pill's percentage is swapped for the
  # system monitor's gauge (config/dms/BarSystemMonitor.qml), keeping the
  # plugin's level colours; the popout still lists exact percentages.
  # Solaar vendors hid_parser, which its own
  # propagated hid-parser also provides, hence ignoreCollisions.
  deviceBatteriesPython =
    (pkgs.python3.withPackages (ps: [
      (ps.toPythonModule pkgs.solaar)
      ps.dbus-python
      ps.pygobject3
      ps.pyudev
    ])).override
      { ignoreCollisions = true; };
  deviceBatteries = pkgs.runCommand "dms-plugin-deviceBatteries" { } ''
    cp -r ${registry.deviceBatteries} $out
    chmod -R u+w $out
    substituteInPlace $out/DeviceBatteriesDaemon.qml \
      --replace-fail 'command: ["python3", root.helper' \
                     'command: ["${lib.getExe deviceBatteriesPython}", root.helper'
    substituteInPlace $out/DeviceBatteries.qml \
      --replace-fail 'StyledText {
                    text: root.lowest ? root.lowest.percent + "%" : ""
                    font.pixelSize: root.textSize
                    color: root.levelColor(root.lowest)
                    anchors.verticalCenter: parent.verticalCenter
                }' \
                     'Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(3, Math.round(root.iconSize * 0.22))
                    height: Math.round(root.iconSize * 0.85)
                    radius: width / 2
                    color: Theme.withAlpha(Theme.surfaceText, 0.18)
                    visible: root.lowest !== null

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: parent.height * Math.max(0, Math.min(1, (root.lowest?.percent ?? 0) / 100))
                        radius: parent.radius
                        color: root.levelColor(root.lowest)
                    }
                }' \
      --replace-fail 'StyledText {
                    text: root.lowest ? root.lowest.percent : ""
                    font.pixelSize: root.textSize
                    color: root.levelColor(root.lowest)
                    anchors.horizontalCenter: parent.horizontalCenter
                }' \
                     'Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(3, Math.round(root.iconSize * 0.22))
                    height: Math.round(root.iconSize * 0.85)
                    radius: width / 2
                    color: Theme.withAlpha(Theme.surfaceText, 0.18)
                    visible: root.lowest !== null

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: parent.height * Math.max(0, Math.min(1, (root.lowest?.percent ?? 0) / 100))
                        radius: parent.radius
                        color: root.levelColor(root.lowest)
                    }
                }'
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
      # screen recording. No bar pill, only a Control Center tile: Print opens its
      # menu floating (above). Its tools are in home.packages
      # (dms.nix).
      id = "quickCapture";
      src = quickCapture;
    }
    {
      # Local: a Control Center tile that opens the keybind overlay (Super+/).
      id = "keybindsTile";
      src = ../../../config/dms/keybindsTile;
    }
  ]
  # Local: a Control Center toggle that starts/stops the lan-mouse daemon
  # (home/max/lan-mouse.nix), on the hosts that run it.
  ++ lib.optional lanMouse.enable {
    id = "lanMouseTile";
    src = ../../../config/dms/lanMouseTile;
  }
  # Clight's Control Center tile (hosts/common/optional/clight.nix): ambient
  # and backlight levels, pause, and its settings — over Clight's D-Bus API,
  # so nothing to install beyond the service.
  ++ lib.optional osConfig.services.clight.enable {
    id = "dankClight";
    src = clight;
  }
  ++ lib.optional osConfig.services.tailscale.enable {
    id = "dankscale";
    src = dankscale;
  }
  # Replaces the built-in battery pill: same icon + percent, but its popout
  # (and Control Center tile) adds UPower's charge history, health/drain stats
  # and power profiles. The profile buttons need power-profiles-daemon, so under
  # TLP (framework's powersave entry) they do nothing.
  ++ lib.optional isLaptop {
    id = "batteryPlus";
    src = registry.batteryPlus;
  }
  ++ [
    {
      id = "deviceBatteries";
      src = deviceBatteries;
    }
  ];

  has = id: lib.any (p: p.id == id) plugins;
in
{
  configFiles = lib.listToAttrs (
    map (p: lib.nameValuePair "dms/plugins/${p.dir or p.id}" { source = p.src; }) plugins
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
  # dms.nix.
  barWidget = id: lib.optional (has id) id;
}
