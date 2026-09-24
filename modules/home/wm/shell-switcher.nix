# modules/home/wm/shell-switcher.nix — swap between two desktop shells.
#
# Installs DMS (DankMaterialShell) alongside this config's own Quickshell
# panels, and gives each one a systemd user unit.
#
# The units are mutually exclusive via Conflicts=: both shells register
# org.freedesktop.Notifications, so two running at once means one of them
# silently loses its notification daemon (and both draw a bar). Letting
# systemd enforce that — rather than pkill in the switcher script — makes the
# swap a single transaction: starting one unit stops the incumbent first.
#
# Driven by config/hypr-scripts/shell-switch.sh, bound to SUPER+ALT+1 (own),
# SUPER+ALT+3 (DMS) and SUPER+ALT+S in config/hypr/hyprland.lua. The choice is recorded under
# $XDG_STATE_HOME/hypr/active-shell and re-applied at login by
# shell-restore.service.
#
# DMS is themed from config/stylix/palette.nix like every other app here, via
# its own custom-scheme mechanism (see "Theming" below), and hands its
# wallpaper picks to awww so that stays the single wallpaper owner.
{
  lib,
  config,
  pkgs,
  machineType,
  osConfig,
  inputs,
  ...
}:
let
  cfg = config.custom.hm;

  renderTheme = import ../../../config/stylix/palette-subst.nix { inherit lib; };
  outputs = import ./outputs.nix { inherit lib; } cfg;
  isLaptop = machineType == "laptop";

  dmsPlugins = import ./dms-plugins.nix {
    inherit
      lib
      pkgs
      inputs
      osConfig
      isLaptop
      ;
  };

  scriptsDir = "${config.home.homeDirectory}/.config/hypr/scripts";
  # Deployed 0444 (see hyprland.nix), so invoke through bash rather than
  # exec'ing the script directly — a direct exec dies with 126.
  switch = "${pkgs.bash}/bin/bash ${scriptsDir}/shell-switch.sh";

  # ── Lua dispatch fixups ─────────────────────────────────────────────────────
  # DMS 1.6 routes every Hyprland dispatch through Services/HyprlandService.qml
  # and speaks Lua when the compositor is on it (luaConfigActive), so the
  # per-call-site rewrites 1.4.6 needed are gone. One gap remains: window
  # targets. It passes `window = "address:0x…"` as a bare string, which
  # Hyprland accepts and ignores; they have to go through hl.get_window() (see
  # the hyprland-lua-dispatch notes). Overview clicks, drags and closes, and the
  # window switcher's focus, all go through these three functions.
  #
  # substituteInPlace on the installed QML rather than a .patch file: it is
  # plain text at a stable path, and --replace-fail turns a version bump that
  # reworded a call site into a BUILD failure rather than a silent return to
  # dead clicks.
  #
  # patchQml also carries patches that aren't about dispatch, after the
  # dispatch ones: caffeine icons, tooltips and widget tweaks.
  patchQml =
    pkg: subs:
    pkg.overrideAttrs (old: {
      postInstall =
        (old.postInstall or "")
        + lib.concatMapStrings (s: ''
          substituteInPlace "$out/${s.file}" \
            --replace-fail ${lib.escapeShellArg s.from} ${lib.escapeShellArg s.to}
        '') subs;
    });

  dms-shell =
    (patchQml pkgs.dms-shell (
      let
        hs = "share/quickshell/dms/Services/HyprlandService.qml";
      in
      [
        {
          file = hs;
          from = "Hyprland.dispatch(`hl.dsp.focus({ window = \${luaString(selector)} })`);";
          to = "Hyprland.dispatch(`hl.dsp.focus({ window = hl.get_window(\${luaString(selector)}) })`);";
        }
        {
          file = hs;
          from = "Hyprland.dispatch(`hl.dsp.window.close(\${luaString(selector)})`);";
          to = "Hyprland.dispatch(`hl.dsp.window.close({ window = hl.get_window(\${luaString(selector)}) })`);";
        }
        {
          file = hs;
          from = "window = \${luaString(selector)}, follow = ";
          to = "window = hl.get_window(\${luaString(selector)}), follow = ";
        }
        # Left as upstream: dpmsOff/dpmsOn send hl.dsp.dpms({ action = … }), but
        # hl.dsp.dpms has been seen to ignore its argument and toggle. Only
        # DMS's own monitor-off timeouts call them, and those are 0 (off) —
        # hypridle owns screen blanking here.
      ]
      # Not a dispatch fix: coffee icons for the idle inhibitor ("caffeine")
      # instead of upstream's motion sensor. `coffee` (steaming mug) = keeping
      # awake, `local_cafe` (plain cup) = idle allowed, where DMS shows the
      # state; the Control Center tile and its button's status icons use a
      # fixed icon, so they get the mug. --replace-fail swaps every occurrence,
      # so each file's two call sites are covered.
      ++
        map
          (file: {
            inherit file;
            from = ''SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"'';
            to = ''SessionService.idleInhibited ? "coffee" : "local_cafe"'';
          })
          [
            "share/quickshell/dms/Modules/DankBar/Widgets/IdleInhibitor.qml"
            "share/quickshell/dms/Modules/OSD/IdleInhibitorOSD.qml"
          ]
      ++
        map
          (file: {
            inherit file;
            from = ''return "motion_sensor_active";'';
            to = ''return "coffee";'';
          })
          [
            "share/quickshell/dms/Modules/ControlCenter/Components/DragDropGrid.qml"
            "share/quickshell/dms/Modules/DankBar/Widgets/ControlCenterButton.qml"
          ]
      ++
        map
          (file: {
            inherit file;
            from = ''"icon": "motion_sensor_active",'';
            to = ''"icon": "coffee",'';
          })
          [
            "share/quickshell/dms/Modules/ControlCenter/Models/WidgetModel.qml"
            "share/quickshell/dms/Modules/Settings/WidgetsTab.qml"
          ]
      ++ [
        {
          file = "share/quickshell/dms/Modules/Settings/WidgetsTabSection.qml";
          from = ''icon: "motion_sensor_active",'';
          to = ''icon: "coffee",'';
        }
      ]
      # Not a dispatch fix: Noctalia-style hover tooltips on the bar. DMS only
      # has bar tooltips for vertical bars, and only on disk/focused-app. BasePill
      # (every bar widget's base) gains a tooltipText property and an instance
      # of config/dms/BarPillTooltip.qml, installed below; each widget then gets
      # a tooltipText binding inserted after its `id: root`. Empty = no tooltip.
      ++ [
        {
          file = "share/quickshell/dms/Modules/Plugins/BasePill.qml";
          from = "    readonly property bool isMouseHovered: mouseArea.containsMouse\n";
          to = "    readonly property bool isMouseHovered: mouseArea.containsMouse\n    property string tooltipText: \"\"\n";
        }
        {
          file = "share/quickshell/dms/Modules/Plugins/BasePill.qml";
          from = "    property bool _blurRegistered: false";
          to = "    BarPillTooltip {\n        pill: root\n    }\n\n    property bool _blurRegistered: false";
        }
        {
          # Not a dispatch fix: the tray as a drawer, as in Noctalia. DMS
          # already has an overflow popup behind a chevron for icons hidden
          # one by one (SessionData's hidden tray ids); treating every item as
          # hidden leaves only the chevron on the bar. Hiding/unhiding single
          # icons from DMS's tray menu, and 1.6's automatic overflow limit
          # (trayMaxVisibleItems, which can't go below 1), stop mattering.
          file = "share/quickshell/dms/Modules/DankBar/Widgets/SystemTrayBar.qml";
          from = "readonly property var mainBarItemsRaw: visibleSortedTrayItems.slice(0, automaticVisibleItemLimit)";
          to = "readonly property var mainBarItemsRaw: []";
        }
        {
          file = "share/quickshell/dms/Modules/DankBar/Widgets/SystemTrayBar.qml";
          from = "readonly property var hiddenBarItems: allSortedTrayItems.filter(item => hiddenBarItemKeys.indexOf(root.getTrayItemKey(item)) !== -1)";
          to = "readonly property var hiddenBarItems: allSortedTrayItems";
        }
        {
          # With only the chevron on the bar, its slot is the whole pill:
          # upstream sizes it icon + 6px, but the expand_more glyph fills only
          # the middle half of its box. 70 percent of the icon size keeps the
          # glyph whole and the hover highlight with it (horizontal bars only).
          file = "share/quickshell/dms/Modules/DankBar/Widgets/SystemTrayBar.qml";
          from = "            Item {\n                width: root.trayItemSize\n                height: root.barThickness\n                visible: root.hasHiddenItems\n\n                Rectangle {\n                    id: caretButton\n                    width: root.trayItemSize\n";
          to = "            Item {\n                width: Math.round(Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale) * 0.7)\n                height: root.barThickness\n                visible: root.hasHiddenItems\n\n                Rectangle {\n                    id: caretButton\n                    width: parent.width\n";
        }
        {
          # The drawer behaves as one button, like any other pill: the whole
          # pill opens it, with the pill's own hover highlight, cursor and
          # ripple (BasePill's MouseArea, whose clicked signal upstream leaves
          # unhandled here). The chevron's own MouseArea is disabled so clicks
          # and hover fall through to it, and its separate highlight is gone.
          file = "share/quickshell/dms/Modules/DankBar/Widgets/SystemTrayBar.qml";
          from = "    enableBackgroundHover: false\n    enableCursor: false\n";
          to = "    enableBackgroundHover: true\n    enableCursor: true\n    onClicked: if (hasHiddenItems) menuOpen = !menuOpen\n";
        }
      ]
      ++
        lib.concatMap
          (area: [
            {
              file = "share/quickshell/dms/Modules/DankBar/Widgets/SystemTrayBar.qml";
              from = "color: ${area}.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : Theme.withAlpha(BlurService.hoverColor(Theme.widgetBaseHoverColor), 0)";
              to = "color: \"transparent\"";
            }
            {
              file = "share/quickshell/dms/Modules/DankBar/Widgets/SystemTrayBar.qml";
              from = "                        id: ${area}\n                        anchors.fill: parent\n";
              to = "                        id: ${area}\n                        enabled: false\n                        anchors.fill: parent\n";
            }
          ])
          [
            "caretArea"
            "caretAreaVert"
          ]
      ++ [
        {
          # Not a dispatch fix: the focused window pill is app icon + title on
          # horizontal bars. 1.6 draws the icon itself (focusedWindowShowIcon),
          # but keeps the app name beside it; the name only shows now when no
          # icon resolved. The • separator follows it.
          file = "share/quickshell/dms/Modules/DankBar/Widgets/FocusedApp.qml";
          from = "                        visible: text.length > 0\n                    }\n\n                    StyledText {\n                        id: appSeparator\n";
          to = "                        visible: text.length > 0 && !horizontalAppIcon.visible && !horizontalSteamIcon.visible\n                    }\n\n                    StyledText {\n                        id: appSeparator\n";
        }
        {
          file = "share/quickshell/dms/Modules/DankBar/Widgets/FocusedApp.qml";
          from = "                        visible: !compactMode && appText.text && titleText.text\n";
          to = "                        visible: !compactMode && appText.visible && titleText.text\n";
        }
        {
          # Not a dispatch fix: make DMS's Settings → Displays → Configuration
          # page actually do something here. Upstream writes DMS's outputs.lua
          # and reloads Hyprland, but hyprland.lua (read-only, from
          # monitors.lua) never loads that file, so every Apply snapped back.
          # Apply and revert now go live over wlr-output-management —
          # session-only, which is what's wanted; the permanent layout stays in
          # monitors.lua. 1.6 already does exactly this for its Aqueous
          # compositor (WlrOutputService.outputsConfigHeads); VRR is added on
          # top. The Hyprland-only extras (bit depth, HDR, colour management)
          # still go nowhere.
          file = "share/quickshell/dms/Modules/Settings/DisplayConfig/DisplayConfigState.qml";
          from = "    function backendWriteOutputsConfig(outputsData, settingsOrCallback, maybeCallback) {\n";
          to = "    // Hyprland here is configured by a read-only hyprland.lua that never loads\n    // DMS's outputs.lua, so the upstream path (write the file, reload) changes\n    // nothing. Apply the layout live over wlr-output-management instead:\n    // session-only, gone at the next reload/login. Revert goes through the\n    // same function, so the confirmation dialog's countdown undoes a bad\n    // layout live too.\n    function applyOutputsLive(outputsData, finish) {\n        const heads = WlrOutputService.outputsConfigHeads(outputsData, outputs);\n        for (const head of heads) {\n            const o = outputsData[head.name];\n            if (head.enabled && o.vrr_supported)\n                head.adaptiveSync = o.vrr_enabled ? 1 : 0;\n        }\n        WlrOutputService.applyConfiguration(heads, (ok, message) => {\n            if (!ok)\n                console.warn(\"DisplayConfig: live apply failed:\", message);\n            WlrOutputService.requestState();\n            finish(ok);\n        });\n    }\n\n    function backendWriteOutputsConfig(outputsData, settingsOrCallback, maybeCallback) {\n";
        }
        {
          file = "share/quickshell/dms/Modules/Settings/DisplayConfig/DisplayConfigState.qml";
          from = "                const hyprlandSettings = hasExplicitSettings ? settings : buildMergedHyprlandSettings();\n                HyprlandService.generateOutputsConfig(outputsData, hyprlandSettings, finish);\n";
          to = "                applyOutputsLive(outputsData, finish);\n";
        }
        {
          # The include warning box offers to splice a require of outputs.lua
          # into hyprland.lua, which is a store file here and doesn't need it
          # now.
          file = "share/quickshell/dms/Modules/Settings/DisplayConfig/IncludeWarningBox.qml";
          from = "    visible: (showLegacy || showSetup) && DisplayConfigState.hasOutputBackend && !DisplayConfigState.checkingInclude\n";
          to = "    visible: false\n";
        }
        {
          # Not a dispatch fix: album art in the bar's media pill. Upstream
          # shows only a cava visualiser (or a note) before the title; the
          # track's MPRIS art, when it loads, takes that slot as a small
          # rounded thumbnail, and the visualiser returns for tracks without.
          file = "share/quickshell/dms/Modules/DankBar/Widgets/Media.qml";
          from = "import Quickshell.Services.Mpris\n";
          to = "import Quickshell.Services.Mpris\nimport Quickshell.Widgets\n";
        }
        {
          file = "share/quickshell/dms/Modules/DankBar/Widgets/Media.qml";
          from = "                    Item {\n                        width: 20\n                        height: 20\n                        anchors.verticalCenter: parent.verticalCenter\n\n                        AudioVisualization {\n                            anchors.fill: parent\n                            visible: CavaService.cavaAvailable && SettingsData.audioVisualizerEnabled\n                        }\n\n                        DankIcon {\n                            anchors.fill: parent\n                            name: \"music_note\"\n                            size: 20\n                            color: Theme.primary\n                            visible: !CavaService.cavaAvailable || !SettingsData.audioVisualizerEnabled\n                        }\n";
          to = "                    Item {\n                        readonly property bool hasArt: artThumb.status === Image.Ready\n                        width: hasArt ? Math.round(root.widgetThickness * 0.75) : 20\n                        height: width\n                        anchors.verticalCenter: parent.verticalCenter\n\n                        ClippingRectangle {\n                            anchors.fill: parent\n                            radius: Theme.cornerRadius / 2\n                            color: \"transparent\"\n                            visible: parent.hasArt\n\n                            Image {\n                                id: artThumb\n                                anchors.fill: parent\n                                source: activePlayer ? (activePlayer.trackArtUrl || \"\") : \"\"\n                                fillMode: Image.PreserveAspectCrop\n                                sourceSize: Qt.size(96, 96)\n                                asynchronous: true\n                                smooth: true\n                                mipmap: true\n                            }\n                        }\n\n                        AudioVisualization {\n                            anchors.fill: parent\n                            visible: !parent.hasArt && CavaService.cavaAvailable && SettingsData.audioVisualizerEnabled\n                        }\n\n                        DankIcon {\n                            anchors.fill: parent\n                            name: \"music_note\"\n                            size: 20\n                            color: Theme.primary\n                            visible: !parent.hasArt && (!CavaService.cavaAvailable || !SettingsData.audioVisualizerEnabled)\n                        }\n";
        }
        {
          # Not a dispatch fix: plugin popouts lagged on every open. DankPopout's
          # contentLoader is only active while the popout shows, so each click
          # rebuilt the plugin's whole popout from scratch, and PluginPopout
          # then rebinds its height to the freshly loaded content, so the
          # surface opened at the plugin's nominal height and snapped to the
          # real one. After the first open, keep the content loaded: later
          # opens reuse it at its settled size. Plugin popouts only — built-in
          # ones keep upstream's load-on-open.
          file = "share/quickshell/dms/Modules/Plugins/PluginPopout.qml";
          from = "    onBackgroundClicked: close()\n";
          to = ''
            onBackgroundClicked: close()

            property bool keepContentLoaded: false
            onShouldBeVisibleChanged: {
                if (shouldBeVisible)
                    keepContentLoaded = true;
            }
            Binding {
                target: root.contentLoader
                property: "active"
                value: true
                when: root.keepContentLoaded
            }
          '';
        }
      ]
      ++
        lib.mapAttrsToList
          (widget: body: {
            file = "share/quickshell/dms/Modules/DankBar/Widgets/${widget}.qml";
            from = "BasePill {\n    id: root\n";
            to =
              "BasePill {\n    id: root\n\n"
              + lib.concatMapStringsSep "\n" (l: lib.optionalString (l != "") "    ${l}") (
                lib.splitString "\n" body
              );
          })
          {
            RamMonitor = ''
              tooltipText: "Memory " + (DgopService.usedMemoryMB / 1024).toFixed(1) + " / " + (DgopService.totalMemoryMB / 1024).toFixed(1) + " GiB (" + Math.round(DgopService.memoryUsage) + "%)" + (DgopService.totalSwapKB > 0 ? "\nSwap " + (DgopService.usedSwapKB / 1048576).toFixed(1) + " / " + (DgopService.totalSwapKB / 1048576).toFixed(1) + " GiB" : "")
            '';
            CpuTemperature = ''
              tooltipText: (DgopService.cpuTemperature > 0 ? "CPU temperature " + Math.round(DgopService.cpuTemperature) + "°C" : "CPU temperature unavailable") + (DgopService.cpuModel ? "\n" + DgopService.cpuModel : "")
            '';
            GpuTemperature = ''
              tooltipText: displayTemp > 0 ? "GPU temperature " + Math.round(displayTemp) + "°C" : "GPU temperature\nEnable the GPU under Processes → System"
            '';
            Clock = ''
              tooltipText: Qt.formatDate(tooltipClock.date, "dddd d MMMM yyyy")

              SystemClock {
                  id: tooltipClock
                  precision: SystemClock.Minutes
              }
            '';
            Weather = ''
              tooltipText: {
                  const w = WeatherService.weather;
                  if (!w.available)
                      return "";
                  const today = w.forecast && w.forecast.length > 0 ? w.forecast[0] : null;
                  let s = WeatherService.getWeatherCondition(w.wCode) + " · " + WeatherService.formatTemp(w.temp) + ", feels like " + WeatherService.formatTemp(w.feelsLike);
                  if (today)
                      s += "\nHigh " + WeatherService.formatTemp(today.tempMax) + " · low " + WeatherService.formatTemp(today.tempMin) + " · rain " + today.precipitationProbability + "%";
                  s += "\nHumidity " + w.humidity + "% · wind " + WeatherService.formatSpeed(w.wind);
                  if (w.city)
                      s += "\n" + w.city;
                  return s;
              }
            '';
            IdleInhibitor = ''
              tooltipText: SessionService.idleInhibited ? "Keeping awake\nClick to allow idle" : "Idle allowed\nClick to keep awake"
            '';
            # Upstream's own disk tooltip still handles vertical bars.
            DiskUsage = ''
              tooltipText: !isVerticalOrientation && selectedMount ? (selectedMount.mount === "/" ? "Disk" : selectedMount.mount) + " · " + selectedMount.used + " of " + selectedMount.size + " used (" + selectedMount.percent + ")\n" + selectedMount.avail + " free" : ""
            '';
          }
    )).overrideAttrs
      (old: {
        postInstall = old.postInstall + ''
          chmod u+w "$out/share/quickshell/dms/Widgets"
          install -Dm444 ${../../../config/dms/BarPillTooltip.qml} \
            "$out/share/quickshell/dms/Widgets/BarPillTooltip.qml"
          # CPU + memory + GPU in one pill with usage gauges; replaces the
          # cpuUsage widget in place — see the header of the QML file.
          chmod u+w "$out/share/quickshell/dms/Modules/DankBar/Widgets"
          install -Dm444 ${../../../config/dms/BarSystemMonitor.qml} \
            "$out/share/quickshell/dms/Modules/DankBar/Widgets/CpuMonitor.qml"
        '';
      });

  # ── Bar layouts, mirroring modules/home/wm/waybar.nix ───────────────────────
  # Waybar's main bar is  workspaces/scratchpad/window | clock/weather |
  # mpris, {cpu,mem,temp,gpu}, disk, {recording,camera,mic,audio,bt,net},
  # battery, idle-inhibitor, tray, rebuild, keybinds, notifications, settings —
  # and a trimmed portrait bar. DMS lacks some counterparts:
  #   • no scratchpad, rebuild (NixPanel) or keybinds widget
  #   • no volume/network/bluetooth bar widgets at all (they live behind its
  #     control centre button)
  #   • camera+mic fold into one privacyIndicator; recording has no home
  # Declaring these means per-widget tweaks made in a shell's own GUI are
  # overwritten on the next nixup — the arrays are replaced, not merged.
  # DMS's own default barConfigs[0], copied verbatim from dms-shell 1.6.2's
  # Common/settings/SettingsSpec.js. Only used to seed a settings.json that has
  # no barConfigs yet — see the activation script below.
  #
  # It has to be the *complete* object, not just the keys we override:
  # SettingsStore.js `parse` assigns `root[k] = raw` wholesale and barConfigs has
  # no coerce, so any key missing from the seed stays undefined rather than
  # falling back to the spec default. An undefined `enabled` in particular means
  # SettingsData's `barConfigs.filter(cfg => cfg.enabled)` drops the bar and
  # nothing renders at all.
  #
  # Re-check this against SettingsSpec.js when bumping dms-shell: keys added
  # upstream after 1.6.2 would land undefined on a first-run seed.
  dmsDefaultBar = {
    id = "default";
    name = "Main Bar";
    enabled = true;
    position = 0;
    screenPreferences = [ "all" ];
    showOnLastDisplay = true;
    leftWidgets = [
      "launcherButton"
      "workspaceSwitcher"
      "focusedWindow"
    ];
    centerWidgets = [
      "music"
      "clock"
      "weather"
    ];
    rightWidgets = [
      "systemTray"
      "clipboard"
      "cpuUsage"
      "memUsage"
      "notificationButton"
      "battery"
      "controlCenterButton"
    ];
    spacing = 4;
    innerPadding = 4;
    barLengthPadding = 0;
    attachToScreenEdge = false;
    batteryColorMode = "theme";
    bottomGap = 0;
    transparency = 1.0;
    widgetTransparency = 1.0;
    squareCorners = false;
    noBackground = false;
    maximizeWidgetIcons = false;
    maximizeWidgetText = false;
    removeWidgetPadding = false;
    widgetPadding = 8;
    gothCornersEnabled = false;
    gothCornerRadiusOverride = false;
    gothCornerRadiusValue = 12;
    borderEnabled = false;
    borderColor = "surfaceText";
    borderOpacity = 1.0;
    borderThickness = 1;
    widgetOutlineEnabled = false;
    widgetOutlineColor = "primary";
    widgetOutlineOpacity = 1.0;
    widgetOutlineThickness = 1;
    fontScale = 1.0;
    iconScale = 1.0;
    autoHide = false;
    autoHideDelay = 250;
    autoHideStrict = false;
    useOverlayLayer = false;
    showOnWindowsOpen = false;
    openOnOverview = false;
    visible = true;
    popupGapsAuto = true;
    popupGapsManual = 4;
    maximizeDetection = true;
    scrollEnabled = true;
    scrollXBehavior = "column";
    scrollYBehavior = "workspace";
    shadowIntensity = 0;
    shadowOpacity = 60;
    shadowColorMode = "default";
    shadowCustomColor = "#000000";
    clickThrough = false;
    hoverPopouts = false;
    hoverPopoutDelay = 150;
  };

  dmsDeclared = {
    barDefault = dmsDefaultBar;
    settings = {
      currentThemeName = "custom";
      currentThemeCategory = "custom";
      # As above: DMS resolves and caches the coordinates into its own
      # SessionData once auto-location is on.
      useAutoLocation = true;
      weatherEnabled = true;
      showWeather = true;
      # Waybar numbers its workspaces; DMS ships unlabelled dots.
      showWorkspaceIndex = true;
      # Exactly what DMS's "Disable Built-in Wallpapers" toggle writes: no screen
      # renders its own wallpaper layer, so a pick can't stack over awww.
      # dms-wallpaper-bridge forwards picks to awww instead.
      screenPreferences.wallpaper = [ ];
      customThemeFile = "${config.xdg.configHome}/DankMaterialShell/gruvbox-material.json";
    };
    # Control Center tiles to strip. Dark Mode would flip DMS off the fixed
    # Gruvbox Material Dark scheme; Night Mode is a second gamma client racing
    # the gammastep service. Filtered out of whatever list DMS has saved rather
    # than replacing it, so tiles added and per-tile tweaks made in its GUI
    # (the brightness slider's DDC device) survive.
    controlCenterDrop = [
      "darkMode"
      "nightMode"
    ];
    # Plugin tiles appended when missing — only on hosts with the plugin.
    # Once there, their position and width are DMS's to keep.
    controlCenterAdd = map (id: {
      id = "plugin_${id}";
      enabled = true;
      width = 50;
    }) (dmsPlugins.barWidget "batteryPlus");
    bars = {
      # "all" when there is nothing to split, so single-output hosts still show a bar.
      mainScreens = if outputs.hasPortrait then outputs.landscapeOutputs else [ "all" ];
      portraitScreens = outputs.portraitOutputs;
      # Plugin pills (dms-plugins.nix) are each [ ] on a host without that
      # plugin. They fit on the right now that Claude and Nix Monitor are
      # icon-sized; at full size they ran the right section into the centre.
      left = [
        "workspaceSwitcher"
        "focusedWindow"
      ];
      # music sits with the clock, as in DMS's own default: in the right
      # section a playing track pushed it into the centre group.
      # Odd count with the clock in the middle: in DMS's default "index"
      # centeringMode that pins the clock to the exact centre of the bar,
      # whatever its neighbours' widths.
      center = [
        "music"
        "clock"
        "weather"
      ];
      # "cpuUsage" is config/dms/BarSystemMonitor.qml (installed over
      # CpuMonitor.qml above): CPU, memory and GPU in one pill, so cpuTemp,
      # memUsage and gpuTemp aren't listed.
      right = [
        "cpuUsage"
      ]
      ++ dmsPlugins.barWidget "dankKDEConnect"
      ++ dmsPlugins.barWidget "claudeUsage"
      ++ dmsPlugins.barWidget "dankscale"
      ++ dmsPlugins.barWidget "nixMonitor"
      ++ [ "privacyIndicator" ]
      ++ dmsPlugins.barWidget "batteryPlus"
      ++ [
        "idleInhibitor"
        "systemTray"
        "notificationButton"
        "controlCenterButton"
      ];
      # DankBarWindow.qml reads barConfig.transparency straight into the
      # background alpha despite the name, so 0 is fully transparent and
      # widgetTransparency 1 keeps the widget pills opaque. Already the
      # shipped default; declared so it survives a reset.
      barAlpha = 0;
      widgetAlpha = 1;
      pLeft = [ "workspaceSwitcher" ];
      pCenter = [ "clock" ];
      pRight = [
        "notificationButton"
        "controlCenterButton"
      ];
    };
  };

  dmsDecl = pkgs.writeText "dms-declared.json" (builtins.toJSON dmsDeclared);
  dmsPluginDecl = pkgs.writeText "dms-plugins-declared.json" (builtins.toJSON dmsPlugins.settings);

  shells = {
    own = {
      description = "Desktop shell: this config's Quickshell panels + Waybar";
      exec = "${pkgs.quickshell}/bin/quickshell -p ${scriptsDir}/quickshell/Shell.qml";
      # Waybar is this shell's bar; it is PartOf shell-own.service (see
      # waybar.nix) so it comes and goes with it.
      wants = [ "waybar.service" ];
    };
    dms = {
      description = "Desktop shell: DankMaterialShell";
      # --session is upstream's own systemd invocation: stays in the
      # foreground and expects to be session-managed.
      exec = "${dms-shell}/bin/dms run --session";
      wants = [
        "shell-utility.service"
        # Watch for wallpaper picks, and apply any existing one once at start.
        "dms-wallpaper-bridge.path"
        "dms-wallpaper-bridge.service"
      ];
    };
  };

  # Same Shell.qml as shell-own.service, run alongside DMS so the panels it has
  # no counterpart for (Nix, Monitors, KDEConnect, Input) stay on their
  # keybinds.
  # QS_UTILITY_MODE makes it skip the notification server, the OSD and the
  # waybar bridge, which are the only parts that would fight the active shell.
  #
  # It Conflicts with shell-own.service rather than joining the three-way web:
  # exactly one Shell.qml may run, because qs_manager.sh addresses it by config
  # path and a second instance would make that IPC ambiguous.
  utilityUnit = {
    Unit = {
      Description = "Own Quickshell panels, alongside DMS";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      Requisite = [ "graphical-session.target" ];
      Conflicts = [ "shell-own.service" ];
    };
    Service = {
      Type = "simple";
      Environment = [ "QS_UTILITY_MODE=1" ];
      ExecStart = "${pkgs.quickshell}/bin/quickshell -p ${scriptsDir}/quickshell/Shell.qml";
      SuccessExitStatus = "143 SIGTERM";
      Restart = "on-failure";
      RestartSec = 2;
      Slice = "session.slice";
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
      Conflicts =
        lib.filter (u: u != unitName name) allUnits ++ lib.optional (name == "own") "shell-utility.service";
      Wants = shell.wants;
    };
    Service = {
      Type = "simple";
      ExecStart = shell.exec;
      # Record the running shell and switch caffeine on from the unit itself, so
      # both hold however it was started (see `started` in shell-switch.sh).
      ExecStartPost = "${switch} started ${name}";
      # dms exits 143 on SIGTERM rather than dying by signal, so without this
      # every Conflicts-driven swap leaves the unit in `failed` — which then
      # hides a genuine crash. Restart still covers the real thing.
      SuccessExitStatus = "143 SIGTERM";
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
      dms-shell
      # DMS's CPU/memory/temperature/disk widgets and its process list all read
      # from dgop, which dms-shell doesn't depend on; without it they're blank.
      pkgs.dgop
      # The launcher's "paste" action types Ctrl+V into the focused window.
      pkgs.wtype
      # quickCapture (dms-plugins.nix): recording (gpu-screen-recorder comes
      # from streaming-tools.nix where a host has it; wf-recorder is the CPU
      # fallback), PDF export, OCR and QR scanning. Its ffmpeg and ImageMagick
      # are already in home/max/packages.nix.
      pkgs.wf-recorder
      pkgs.img2pdf
      pkgs.tesseract
      pkgs.zbar
      # The launcher's Files tab and `/` queries; DMS only probes for the binary
      # and pings the dsearch service below.
      pkgs.dsearch
    ];

    # ── Theming ───────────────────────────────────────────────────────────────
    # DMS reads a user-supplied scheme file that it never writes back to, so
    # unlike its settings.json this can be a plain store symlink rendered from
    # palette.nix.
    xdg.configFile = {
      "DankMaterialShell/gruvbox-material.json".text =
        renderTheme ../../../config/dms/gruvbox-material.json;
    }
    # DMS plugins: one store symlink per plugin directory — see dms-plugins.nix.
    // dmsPlugins.configFiles;

    # Pointing DMS AT its scheme and layout has to be done differently:
    # settings.json is owned and rewritten by the shell itself, so it can't be a
    # store symlink (it would lose every setting it saves). Merge in only the
    # keys we declare and leave the rest alone.
    systemd.user.paths.dms-wallpaper-bridge = {
      Unit = {
        Description = "Watch DMS session state for wallpaper picks";
        PartOf = [ "shell-dms.service" ];
      };
      Path = {
        PathChanged = "${config.xdg.stateHome}/DankMaterialShell/session.json";
        Unit = "dms-wallpaper-bridge.service";
      };
    };

    home.activation.shellSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      apply() {
        local file="$1" decl="$2" prog="$3"
        $DRY_RUN_CMD mkdir -p "$(dirname "$file")"
        # DMS loads JSON over its Store property defaults, so seeding an empty
        # object is enough when it has never run.
        [ -s "$file" ] || $DRY_RUN_CMD sh -c "echo '{}' > '$file'"
        $DRY_RUN_CMD ${pkgs.jq}/bin/jq --argjson d "$(cat "$decl")" "$prog" "$file" \
          > "$file.hm-tmp" && $DRY_RUN_CMD mv "$file.hm-tmp" "$file"
      }

      # Stale compiled QML: see `stamp` in dms-plugins.nix. Deleting the cache
      # under a running shell is safe; it recompiles on its next start.
      qmlStamp="${config.xdg.cacheHome}/quickshell/dms-plugins.stamp"
      if [ "$(cat "$qmlStamp" 2>/dev/null)" != "${dmsPlugins.stamp}" ]; then
        $DRY_RUN_CMD rm -f "${config.xdg.cacheHome}"/quickshell/qmlcache/*.qmlc
        $DRY_RUN_CMD mkdir -p "$(dirname "$qmlStamp")"
        $DRY_RUN_CMD sh -c "echo ${dmsPlugins.stamp} > '$qmlStamp'"
      fi

      # DMS plugin_settings.json: which plugins are on, plus a few settings.
      # Same plain merge — each plugin's other keys are whatever it saved.
      apply "${config.xdg.configHome}/DankMaterialShell/plugin_settings.json" \
        ${dmsPluginDecl} \
        '. * $d'

      # DMS: the theme keys merge the same way, but its bars can't — a barConfig
      # carries styling (spacing, transparency, corners…) alongside its widget
      # arrays, and replacing the array wholesale would discard all of it. So
      # rewrite the widget lists in place, and clone bar 0 for the portrait
      # output rather than authoring a second bar from scratch.
      apply "${config.xdg.configHome}/DankMaterialShell/settings.json" \
        ${dmsDecl} \
        '($d.settings) as $s
         | . * $s
         # Never run → DMS falls back to its stock list, which has the dropped
         # tiles in it, so seed that list (SettingsData.qml) before filtering.
         | .controlCenterWidgets = (
             (.controlCenterWidgets // ([
                "volumeSlider", "brightnessSlider", "wifi", "bluetooth",
                "audioOutput", "audioInput", "nightMode", "darkMode"
              ] | map({ id: ., enabled: true, width: 50 })))
             | map(select(.id as $i | $d.controlCenterDrop | index($i) | not)))
         | reduce $d.controlCenterAdd[] as $w (.;
             if any(.controlCenterWidgets[]; .id == $w.id)
             then . else .controlCenterWidgets += [$w] end)
         # barConfigs is written by DMS itself, not by the empty-object seed in
         # apply(), so on a machine where DMS has never run there was nothing
         # here to rewrite: the bar came up with stock widgets and DMSs own
         # transparency 1.0, i.e. opaque. Seed the default entry DMS would have
         # written so the overrides below always land on a complete barConfig.
         | if ((.barConfigs | type) == "array") and ((.barConfigs | length) > 0)
           then . else .barConfigs = [ $d.barDefault ] end
         | (.barConfigs[0] |= (
               .transparency       = $d.bars.barAlpha
             | .widgetTransparency = $d.bars.widgetAlpha
             | .screenPreferences = $d.bars.mainScreens
             | .leftWidgets       = $d.bars.left
             | .centerWidgets     = $d.bars.center
             | .rightWidgets      = $d.bars.right))
         | if ($d.bars.portraitScreens | length) > 0
           then
             (if any(.barConfigs[]; .id == "portrait")
              then . else .barConfigs += [.barConfigs[0] | .id = "portrait"] end)
             | .barConfigs |= map(
                 if .id == "portrait"
                 then ( .name             = "Portrait"
                      # Without this the portrait bar falls back onto the
                      # only remaining screen whenever DP-2 is unplugged
                      # (DankBar.qml:168), stacking two bars on DP-3. The
                      # fallback is right for the main bar, not a second one.
                      | .showOnLastDisplay = false
                      | .screenPreferences = $d.bars.portraitScreens
                      | .leftWidgets       = $d.bars.pLeft
                      | .centerWidgets     = $d.bars.pCenter
                      | .rightWidgets      = $d.bars.pRight )
                 else . end)
           else . end'
    '';

    systemd.user.services =
      lib.mapAttrs' (name: shell: {
        name = "shell-${name}";
        value = mkShellUnit name shell;
      }) shells
      // {
        shell-utility = utilityUnit;

        # Applies wallpapers picked in DMS through awww; see the script header.
        dms-wallpaper-bridge = {
          Unit.Description = "Apply DMS wallpaper picks through awww";
          Service = {
            Type = "oneshot";
            Environment = [
              "PORTRAIT_OUTPUTS=${lib.concatStringsSep "," outputs.portraitOutputs}"
              # A user unit doesn't inherit the login shell's PATH.
              "PATH=${
                lib.makeBinPath [
                  pkgs.jq
                  pkgs.coreutils
                  pkgs.gnugrep
                ]
              }:/run/current-system/sw/bin:${config.home.profileDirectory}/bin"
            ];
            ExecStart = "${pkgs.bash}/bin/bash ${scriptsDir}/dms-wallpaper-bridge.sh";
          };
        };

        # File index behind the DMS launcher's file search. Same unit dsearch
        # ships in lib/systemd/user (HM doesn't pick those up). Runs whichever
        # shell is active; it's idle apart from inotify once the index is built.
        # Listens on a unix socket plus 127.0.0.1:43654.
        dsearch = {
          Unit = {
            Description = "dsearch filesystem search service";
            Documentation = "https://github.com/AvengeMedia/dsearch";
          };
          Service = {
            ExecStart = "${lib.getExe pkgs.dsearch} serve";
            Restart = "on-failure";
            RestartSec = 5;
          };
          Install.WantedBy = [ "default.target" ];
        };

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
