# modules/home/wm/dms.nix — the desktop shell: DMS (DankMaterialShell).
#
# Installs DMS, patches the places where it doesn't fit this config (Lua
# dispatch, the read-only hyprland.lua, a few bar widgets) and runs it as
# shell-dms.service, started with the graphical session.
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
  palette = import ../../../config/stylix/palette.nix;
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

  # Scripts here are deployed 0444 (see hyprland.nix), so invoke them through
  # bash rather than exec'ing directly — a direct exec dies with 126.
  scriptsDir = "${config.home.homeDirectory}/.config/hypr/scripts";

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
      # Not a dispatch fix: friendlier key names in the keybind overlay
      # (Super+/). It prints Hyprland's raw names; mouse buttons and the wheel
      # get words, as on the cheat-sheet wallpaper, and the XF86 media keys get
      # Nerd Font icons (DMS's mono font has none, so those labels name the
      # system Nerd Font).
      ++ (
        let
          pad = lib.concatStrings (lib.genList (_: " ") 64);
          cp = c: "String.fromCodePoint(0x${c})";
          labels = lib.concatStringsSep ", " (
            lib.mapAttrsToList (k: v: ''"${k}": ${v}'') {
              "mouse:272" = ''"Drag"'';
              "mouse:273" = ''"Right-drag"'';
              WheelScrollDown = ''"Scroll down"'';
              WheelScrollUp = ''"Scroll up"'';
              XF86AudioRaiseVolume = cp "F075D";
              XF86AudioLowerVolume = cp "F075E";
              XF86AudioMute = cp "F0581";
              XF86AudioPlay = cp "F040E";
              XF86AudioNext = cp "F04AD";
              XF86AudioPrev = cp "F04AE";
              XF86MonBrightnessUp = cp "F00E0";
              XF86MonBrightnessDown = cp "F00DE";
            }
          );
        in
        [
          {
            file = "share/quickshell/dms/Modals/KeybindsContent.qml";
            from =
              ''text: (modelData.key || "").replace(/\+/g, " + ")''
              + "\n${pad}font.pixelSize: Theme.fontSizeSmall\n";
            to =
              lib.concatMapStrings (l: "${l}\n${pad}") [
                "readonly property var keyLabels: ({ ${labels} })"
                ''readonly property bool iconKey: (modelData.key || "").indexOf("XF86") !== -1''
                ''text: (modelData.key || "").split("+").map(k => keyLabels[k] ?? k).join(" + ")''
                ''font.family: iconKey ? "JetBrainsMono Nerd Font" : resolvedFontFamily''
              ]
              + "font.pixelSize: iconKey ? Theme.fontSizeLarge : Theme.fontSizeSmall\n";
          }
        ]
      )
      # Not a dispatch fix: Settings as a dropdown. Upstream's is a movable,
      # maximisable window; here Hyprland places it under the bar at the top
      # right (the dms-settings-dropdown rule in hyprland.lua) and it closes
      # once focus leaves DMS. It stays an xdg toplevel rather than a layer
      # panel on purpose: its theme/plugin/widget browsers and file pickers
      # are child windows, and Hyprland draws every layer surface above
      # windows, so a panel would bury them.
      ++ (
        let
          sm = "share/quickshell/dms/Modals/Settings/SettingsModal.qml";
        in
        [
          {
            # No dragging it around or double-click maximise from the header.
            file = sm;
            from = "                MouseArea {\n                    anchors.fill: parent\n                    onPressed: windowControls.tryStartMove()\n                    onDoubleClicked: windowControls.tryToggleMaximize()\n                }\n\n";
            to = "";
          }
          {
            file = sm;
            from = "                        visible: windowControls.canMaximize\n";
            to = "                        visible: false\n";
          }
          {
            # Close on focus-out, keyed on the whole app rather than this
            # window: Settings' own child windows (and DMS popouts opened over
            # it) keep Qt's application state active, so they don't close it;
            # focusing another app, or clicking empty desktop, does. The short
            # delay rides out the focus hand-off while a child window maps.
            #
            # Armed only once Settings has actually held focus since it
            # opened. The Control Center's settings button opens it while the
            # popout still holds the keyboard, so it maps unfocused; when the
            # popout closes Hyprland refocuses the previous window, and an
            # unarmed focus-out would hide Settings within 200ms of opening.
            # Unarmed, the timer pulls focus to Settings instead.
            file = sm;
            # `from` skips the line's indent, which the '' string strips.
            from = "onClosed: hide()\n";
            to = ''
              onClosed: hide()

                  readonly property var ownToplevel: ToplevelManager.toplevels.values.find(t => t.appId === "com.danklinux.dms" && t.title === settingsModal.title) ?? null
                  readonly property bool ownActivated: ownToplevel?.activated ?? false
                  property bool focusOutArmed: false
                  onOwnActivatedChanged: {
                      if (ownActivated)
                          focusOutArmed = true;
                  }

                  Connections {
                      target: settingsModal
                      function onVisibleChanged() {
                          if (!settingsModal.visible)
                              settingsModal.focusOutArmed = false;
                      }
                  }

                  Connections {
                      target: Qt.application
                      function onStateChanged() {
                          if (settingsModal.visible && Qt.application.state !== Qt.ApplicationActive)
                              focusOutHide.restart();
                          else
                              focusOutHide.stop();
                      }
                  }

                  Timer {
                      id: focusOutHide
                      interval: 200
                      onTriggered: {
                          if (!settingsModal.visible || Qt.application.state === Qt.ApplicationActive)
                              return;
                          if (!settingsModal.focusOutArmed) {
                              if (settingsModal.ownToplevel)
                                  CompositorService.activateToplevel(settingsModal.ownToplevel);
                              return;
                          }
                          settingsModal.hide();
                      }
                  }
            '';
          }
          {
            # ToplevelManager, for the focus-out arming above.
            file = sm;
            from = "import Quickshell\n";
            to = "import Quickshell\nimport Quickshell.Wayland\n";
          }
        ]
      )
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

  # ── Bar layouts ─────────────────────────────────────────────────────────────
  # The main bar, and a trimmed one for portrait outputs. Declaring these means
  # per-widget tweaks made in DMS's own GUI are overwritten on the next nixup —
  # the arrays are replaced, not merged. DMS has no volume/network/bluetooth
  # bar widgets (they live behind its control centre button), and camera + mic
  # fold into one privacyIndicator.
  #
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
      # DMS ships unlabelled dots; number the workspaces instead.
      showWorkspaceIndex = true;
      # Exactly what DMS's "Disable Built-in Wallpapers" toggle writes: no screen
      # renders its own wallpaper layer, so a pick can't stack over awww.
      # dms-wallpaper-bridge forwards picks to awww instead.
      screenPreferences.wallpaper = [ ];
      customThemeFile = "${config.xdg.configHome}/DankMaterialShell/gruvbox-material.json";

      # ── Match Hyprland's window styling (config/hypr/hyprland.lua) ──────────
      # Corners follow decoration.rounding.
      cornerRadius = 10;
      # Popouts, control center and the Settings window see-through like kitty.
      # DMS's own blur needs ext-background-effect-v1, which Hyprland 0.55
      # lacks (`dms blur check` → unsupported), so blurEnabled stays off and
      # Hyprland blurs instead: the dms:* layer rule for popouts, and window
      # blur for Settings, which is an ordinary toplevel.
      popupTransparency = 0.85;
      floatingWindowTransparency = 0.85;
      # Popout outline in the active-border blue at its ee alpha. The blur*
      # names are legacy — DMS draws this border whether or not it blurs. It is
      # fixed at 1px (BlurService.borderWidth), against Hyprland's 2.
      blurBorderEnabled = true;
      blurBorderColor = "custom";
      blurBorderCustomColor = palette.blue;
      blurBorderOpacity = 0.93;
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
    # Once there, their width and other per-tile settings are DMS's to keep.
    controlCenterAdd =
      map
        (id: {
          id = "plugin_${id}";
          enabled = true;
          width = 50;
        })
        (
          dmsPlugins.barWidget "batteryPlus"
          ++ dmsPlugins.barWidget "quickCapture"
          ++ dmsPlugins.barWidget "keybindsTile"
        );
    # Tile order, re-applied on every nixup: a drag in DMS's edit mode lasts
    # only until the next rebuild. Tiles not listed (added in the GUI) keep
    # their relative order after these; listed ones a host lacks are skipped.
    controlCenterOrder = [
      "volumeSlider"
      "brightnessSlider"
      "wifi"
      "bluetooth"
      "audioOutput"
      "audioInput"
      "plugin_batteryPlus"
      "plugin_quickCapture"
      "plugin_keybindsTile"
    ];
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
      # background alpha despite the name, so 0 is a fully transparent bar
      # strip. widgetTransparency is the pills' alpha (BasePill.qml), 0.85 to
      # match popupTransparency; the dms:* layer rule in hyprland.lua blurs
      # behind them (its ignore_alpha 0.5 keeps the empty strip unblurred).
      barAlpha = 0;
      widgetAlpha = 0.85;
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

  shellUnit = {
    Unit = {
      Description = "Desktop shell: DankMaterialShell";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      Wants = [
        # Watch for wallpaper picks, and apply any existing one once at start.
        "dms-wallpaper-bridge.path"
        "dms-wallpaper-bridge.service"
      ];
    };
    Service = {
      Type = "simple";
      # --session is upstream's own systemd invocation: stays in the
      # foreground and expects to be session-managed.
      ExecStart = "${dms-shell}/bin/dms run --session";
      # dms exits 143 on SIGTERM rather than dying by signal, so without this
      # every stop (gaming mode, a rebuild) leaves the unit in `failed` — which
      # then hides a genuine crash. Restart still covers the real thing.
      SuccessExitStatus = "143 SIGTERM";
      Restart = "on-failure";
      RestartSec = 2;
      Slice = "session.slice";
    };
    Install.WantedBy = [ "graphical-session.target" ];
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
         | .controlCenterWidgets |= (. as $w
             | [ $d.controlCenterOrder[] as $id | $w[] | select(.id == $id) ]
             + [ $w[] | select(.id as $i | $d.controlCenterOrder | index($i) | not) ])
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

    systemd.user.services = {
      shell-dms = shellUnit;

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
      # ships in lib/systemd/user (HM doesn't pick those up). It's idle
      # apart from inotify once the index is built.
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
    };
  };
}
