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
  lanMouse,
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
      lanMouse
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
            "share/quickshell/dms/Modules/DBar/Widgets/IdleInhibitor.qml"
            "share/quickshell/dms/Modules/OSD/IdleInhibitorOSD.qml"
            "share/quickshell/dms/Modules/ControlCenter/Details/IdleInhibitorDetail.qml"
            "share/quickshell/dms/Modules/DIsland/IslandSystemSource.qml"
          ]
      ++ [
        {
          file = "share/quickshell/dms/Modules/DBar/Widgets/ControlCenterButton.qml";
          from = ''return "motion_sensor_active";'';
          to = ''return "coffee";'';
        }
        {
          file = "share/quickshell/dms/Modules/ControlCenter/Widgets/IdleInhibitTile.qml";
          from = ''iconName: "motion_sensor_active"'';
          to = ''iconName: "coffee"'';
        }
        {
          # The Dynamic Island's surface takes the bar strip's alpha, which is
          # 0 here (bars.barAlpha), so the expanded island had no background
          # at all: the windows behind showed between its cards, unblurred
          # (below hyprland.lua's ignore_alpha 0.5). Give it the popouts'
          # alpha instead, so it reads like every other DMS panel.
          file = "share/quickshell/dms/Modules/DIsland/IslandBarHost.qml";
          from = "transparency: SettingsData.barTransparency(root.barConfig)";
          to = "transparency: SettingsData.popupTransparency";
        }
        {
          # …and it only reads that alpha with its own chrome. In a normal bar
          # DMS draws it as "band" chrome, an extension of the bar strip that
          # paints the strip's colour, which is fully transparent here. Own
          # chrome, as on island-layout bars, draws its own surface at the
          # alpha above. Frame-hosted bars keep their connected "none" chrome.
          file = "share/quickshell/dms/Modules/DBar/DBarBody.qml";
          from = ''usesConnectedFrameChrome && frameHosted ? "none" : "band"'';
          to = ''usesConnectedFrameChrome && frameHosted ? "none" : "own"'';
        }
        {
          # A bar hosting the island hops from the Top layer to Overlay while
          # the island is open, and back on close. Each hop blanks the whole
          # bar for a frame on Hyprland, so every open and close flickered.
          # Keep it on Top: the open island still sits above every window,
          # it just no longer draws over fullscreen ones, which hide the bar
          # anyway.
          file = "share/quickshell/dms/Modules/DBar/DBarWindow.qml";
          from = "barWindow.usesOverlayLayer || (!isIsland && islandChrome.sheetOut) ? WlrLayer.Overlay";
          to = "barWindow.usesOverlayLayer ? WlrLayer.Overlay";
        }
        {
          # The same bar also grows its layer surface to the open island's
          # height and shrinks it back on close, and Hyprland shows some of
          # those resizes as one empty frame of bar. Size it for the island
          # for good instead (islandHost.hostThickness is a constant: the
          # tallest island panel). Clicks are unaffected: the input mask
          # (DBarWindow.qml) is the bar strip plus the island, not the window.
          file = "share/quickshell/dms/Modules/DBar/DBarBody.qml";
          from = "Math.max(barSurfaceThickness, islandSheetOut ? islandHost.hostThickness : 0)";
          to = "Math.max(barSurfaceThickness, islandHost ? islandHost.hostThickness : 0)";
        }
        {
          # No brightness OSD for changes DMS didn't make. Clight
          # (clight.nix) moves the panel every few seconds, and each move
          # popped the island's brightness face. The brightness keys go
          # through `dms ipc call brightness` (hyprland.lua), which DMS marks
          # as its own (pendingOsdDevices), so they keep their OSD. Still
          # emitted, with showOsd false, for anything else listening.
          file = "share/quickshell/dms/Services/BrightnessService.qml";
          from = "        if (suppressOsd) {\n            return;\n        }\n        brightnessChanged(true);\n    }";
          to = "        brightnessChanged(false);\n    }";
        }
      ]
      # Chrome (and its PWAs) labels every notification's default action
      # "Activate": that's the click-the-notification action (focus the app,
      # open the item), listed as a button for servers that need it. Show it
      # as "Open", DMS's own label for an unlabelled action. Both places that
      # draw action buttons: the card (popups, center) and the island's face.
      ++ [
        {
          file = "share/quickshell/dms/Modules/Notifications/NotificationCard.qml";
          from = ''text: (modelData.text || I18n.tr("Open"))'';
          to = ''text: ((modelData.identifier === "default" ? "" : modelData.text) || I18n.tr("Open"))'';
        }
        {
          file = "share/quickshell/dms/Modules/DIsland/IslandNotificationSource.qml";
          from = "(actions[0].text || I18n.tr(";
          to = ''((actions[0].identifier === "default" ? "" : actions[0].text) || I18n.tr('';
        }
      ]
      ++ [
        {
          # The panel's floor matches Clight's curves (clight.nix) and the
          # old brightnessctl binding: 3% of the hardware range. DMS's scale
          # is offset (raw = (pct - 1) / 99 * max, measured), so its own
          # floor of 1% is raw 0, a black panel, and 4% is raw 3.03%.
          # Applies to the DMS slider too.
          file = "share/quickshell/dms/Services/BrightnessService.qml";
          from = "    function brightnessMinimum(deviceInfo) {\n        if (!deviceInfo";
          to = "    function brightnessMinimum(deviceInfo) {\n        if (deviceInfo?.class === \"backlight\")\n            return 4;\n        if (!deviceInfo";
        }
        {
          # No edit pencil in the Control Center: its layout is declared in
          # this file. DMS re-adds the tile to any saved list without it
          # (ensureEditButton), so it stays in the list and is never shown.
          file = "share/quickshell/dms/Modules/ControlCenter/utils/widgets.js";
          from = "function isShown(widget) {\n    switch (widget?.id) {\n";
          to = "function isShown(widget) {\n    switch (widget?.id) {\n    case EDIT_ID:\n        return false;\n";
        }
        # Night Mode's tile on top of its sunset schedule (session.json, below):
        # a daytime tap forces it warm until sunset, a night-time tap turns it
        # off until sunrise, a second tap cancels either. Upstream's tile only
        # toggles the master switch, which under the schedule does nothing
        # visible by day. The overrides are in-memory; the service re-asserts
        # them after resume (startAutomation, the gamma re-enable) and the
        # excluded-app pause leaves a suppressed night alone.
        {
          file = "share/quickshell/dms/Services/NightModeService.qml";
          from = "    property bool nightModePaused: false\n";
          to = "    property bool nightModePaused: false\n    // Tile overrides on top of the schedule (modules/home/wm/dms.nix):\n    // forced = warm now until the next transition (sunset); suppressed = off\n    // until the next transition (sunrise). Not persisted.\n    property bool nightModeForced: false\n    property bool nightModeSuppressed: false\n    property real nightModeOverrideUntil: 0\n    readonly property bool nightModeWarmNow: nightModeEnabled && (nightModeForced || (!gammaIsDay && !nightModeSuppressed))\n\n    function toggleNightModeNow() {\n        if (!nightModeEnabled || !SessionData.nightModeAutoEnabled) {\n            toggleNightMode();\n            return;\n        }\n        if (nightModeForced || nightModeSuppressed) {\n            _clearNightModeOverride();\n            return;\n        }\n        nightModeOverrideUntil = Date.parse(gammaNextTransition) || (Date.now() + 12 * 3600 * 1000);\n        if (gammaIsDay) {\n            nightModeForced = true;\n            applyNightModeDirectly();\n        } else {\n            nightModeSuppressed = true;\n            _setNightModeEnabled(false, true);\n        }\n    }\n\n    function _clearNightModeOverride() {\n        const wasSuppressed = nightModeSuppressed;\n        nightModeForced = false;\n        nightModeSuppressed = false;\n        nightModeOverrideUntil = 0;\n        if (!wasSuppressed) {\n            startAutomation();\n            return;\n        }\n        _setNightModeEnabled(!nightModePaused, true, success => {\n            if (!success)\n                return;\n            startAutomation();\n            handleNightModeExceptions();\n        });\n    }\n\n    // Minute polling against the wall clock rather than one long Timer, whose\n    // monotonic interval doesn't advance across suspend.\n    Timer {\n        interval: 60000\n        repeat: true\n        running: root.nightModeOverrideUntil > 0\n        onTriggered: {\n            if (Date.now() >= root.nightModeOverrideUntil)\n                root._clearNightModeOverride();\n        }\n    }\n";
        }
        {
          file = "share/quickshell/dms/Services/NightModeService.qml";
          from = "    function startAutomation() {\n        if (!automationAvailable) {\n            return;\n        }\n";
          to = "    function startAutomation() {\n        if (!automationAvailable) {\n            return;\n        }\n        if (nightModeForced) {\n            applyNightModeDirectly();\n            return;\n        }\n";
        }
        {
          file = "share/quickshell/dms/Services/NightModeService.qml";
          from = "    function handleNightModeExceptions() {\n        if (!nightModeEnabled)\n            return;\n";
          to = "    function handleNightModeExceptions() {\n        if (!nightModeEnabled || nightModeSuppressed)\n            return;\n";
        }
        {
          file = "share/quickshell/dms/Services/NightModeService.qml";
          from = "_setNightModeEnabled(!nightModePaused, true, success => {\n                    if (!success)\n                        return;\n                    evaluateNightMode();";
          to = "_setNightModeEnabled(!nightModePaused && !nightModeSuppressed, true, success => {\n                    if (!success)\n                        return;\n                    evaluateNightMode();";
        }
        {
          file = "share/quickshell/dms/Modules/ControlCenter/Widgets/NightModeTile.qml";
          from = "    iconName: NightModeService.nightModeEnabled ? \"nightlight\" : \"dark_mode\"\n    title: I18n.tr(\"Night mode\")\n    active: NightModeService.nightModeEnabled || false\n    available: NightModeService.automationAvailable\n\n    onClicked: NightModeService.toggleNightMode()\n";
          to = "    // A daytime force hands over to the schedule at sunset, which keeps it\n    // warm through the night: from the user's side it lasts until sunrise.\n    readonly property string _nextSunrise: {\n        let t = Date.parse(NightModeService.gammaSunriseTime) || 0;\n        while (t > 0 && t <= Date.now())\n            t += 86400000;\n        return t > 0 ? Qt.formatTime(new Date(t), SettingsData.use24HourClock ? \"HH:mm\" : \"h:mm AP\") : \"\";\n    }\n    readonly property string _overrideTime: Qt.formatTime(new Date(NightModeService.nightModeOverrideUntil || Date.parse(NightModeService.gammaNextTransition)), SettingsData.use24HourClock ? \"HH:mm\" : \"h:mm AP\")\n\n    iconName: NightModeService.nightModeWarmNow ? \"nightlight\" : \"dark_mode\"\n    title: I18n.tr(\"Night mode\")\n    subtitle: {\n        if (!NightModeService.nightModeEnabled)\n            return I18n.tr(\"Off\");\n        if (!SessionData.nightModeAutoEnabled)\n            return SessionData.nightModeTemperature + \"K\";\n        if (NightModeService.nightModeForced)\n            return _nextSunrise ? \"On until \" + _nextSunrise : I18n.tr(\"On\");\n        if (NightModeService.nightModeSuppressed)\n            return \"Off until \" + _overrideTime;\n        return (NightModeService.gammaIsDay ? \"From \" : \"Until \") + _overrideTime;\n    }\n    active: NightModeService.nightModeWarmNow\n    available: NightModeService.automationAvailable\n\n    onClicked: NightModeService.toggleNightModeNow()\n";
        }
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
            "share/quickshell/dms/Common/BarWidgetCatalog.qml"
            "share/quickshell/dms/Modules/Settings/BarWidgetOptions/ControlCenterOptions.qml"
          ]
      # Not a dispatch fix: Noctalia-style hover tooltips on the bar. DMS only
      # has bar tooltips for vertical bars, and only on disk/focused-app. BasePill
      # (every bar widget's base) gains a tooltipText property and an instance
      # of config/dms/BarPillTooltip.qml, installed below; each widget then gets
      # a tooltipText binding inserted after its `id: root`. Empty = no tooltip.
      # Since 2.0 BasePill is a shim over SurfaceWidgets/BarPill, so the
      # property and the instance go there.
      ++ [
        {
          file = "share/quickshell/dms/Modules/SurfaceWidgets/BarPill.qml";
          from = "    readonly property bool isMouseHovered: mouseArea.containsMouse || visualContent.hovered || edgeHovered\n";
          to = "    readonly property bool isMouseHovered: mouseArea.containsMouse || visualContent.hovered || edgeHovered\n    property string tooltipText: \"\"\n";
        }
        {
          file = "share/quickshell/dms/Modules/SurfaceWidgets/BarPill.qml";
          from = "    property var _blurRegisteredWindow: null";
          to = "    BarPillTooltip {\n        pill: root\n    }\n\n    property var _blurRegisteredWindow: null";
        }
        {
          # Not a dispatch fix: the tray as a drawer, as in Noctalia. DMS
          # already has an overflow popup behind a chevron for icons hidden
          # one by one (SessionData's hidden tray ids); treating every item as
          # hidden leaves only the chevron on the bar. Hiding/unhiding single
          # icons from DMS's tray menu, and 1.6's automatic overflow limit
          # (trayMaxVisibleItems, which can't go below 1), stop mattering.
          file = "share/quickshell/dms/Modules/DBar/Widgets/SystemTrayBar.qml";
          from = "readonly property var mainBarItemsRaw: visibleSortedTrayItems.slice(0, automaticVisibleItemLimit)";
          to = "readonly property var mainBarItemsRaw: []";
        }
        {
          file = "share/quickshell/dms/Modules/DBar/Widgets/SystemTrayBar.qml";
          from = "readonly property var hiddenBarItems: allSortedTrayItems.filter(item => hiddenBarItemKeys.indexOf(root.getTrayItemKey(item)) !== -1)";
          to = "readonly property var hiddenBarItems: allSortedTrayItems";
        }
        {
          # With only the chevron on the bar, its slot is the whole pill:
          # upstream sizes it icon + 6px, but the expand_more glyph fills only
          # the middle half of its box. 70 percent of the icon size keeps the
          # glyph whole and the hover highlight with it (horizontal bars only).
          file = "share/quickshell/dms/Modules/DBar/Widgets/SystemTrayBar.qml";
          from = "            Item {\n                width: root.trayItemSize\n                height: root.barThickness\n                visible: root.hasHiddenItems\n\n                BarPillSurface {\n                    id: caretButton\n                    width: root.trayItemSize\n";
          to = "            Item {\n                width: Math.round(Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale) * 0.7)\n                height: root.barThickness\n                visible: root.hasHiddenItems\n\n                BarPillSurface {\n                    id: caretButton\n                    width: parent.width\n";
        }
        {
          # The drawer behaves as one button, like any other pill: the whole
          # pill opens it, with the pill's own hover highlight, cursor and
          # ripple (BasePill's MouseArea, whose clicked signal upstream leaves
          # unhandled here). The chevron's own MouseArea is disabled so clicks
          # and hover fall through to it, and its separate highlight is gone.
          # The handler mirrors the chevron's: the overflow popup has to be
          # positioned and requested, not just flagged open. It anchors on the
          # pill itself: since 2.0 the chevrons live in Loader-built components,
          # out of reach by id (and the chevron is the whole pill anyway).
          file = "share/quickshell/dms/Modules/DBar/Widgets/SystemTrayBar.qml";
          from = "    enableBackgroundHover: false\n    enableCursor: false\n";
          to = "    enableBackgroundHover: true\n    enableCursor: true\n    onClicked: {\n        if (!hasHiddenItems)\n            return;\n        if (!useOverflowPopup)\n            menuOpen = !menuOpen;\n        else if (menuOpen)\n            menuOpen = false;\n        else\n            _openOverflowAt(root);\n    }\n";
        }
      ]
      ++
        lib.concatMap
          (area: [
            {
              file = "share/quickshell/dms/Modules/DBar/Widgets/SystemTrayBar.qml";
              from = "color: Theme.withAlpha(Theme.onSurface, ${area}.pressed ? Theme.stateLayerPressed : ${area}.containsMouse ? Theme.stateLayerHover : 0)";
              to = "color: \"transparent\"";
            }
            {
              file = "share/quickshell/dms/Modules/DBar/Widgets/SystemTrayBar.qml";
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
          file = "share/quickshell/dms/Modules/DBar/Widgets/FocusedApp.qml";
          from = "                        visible: text.length > 0\n                    }\n\n                    StyledText {\n                        id: appSeparator\n";
          to = "                        visible: text.length > 0 && !horizontalAppIcon.visible && !horizontalSteamIcon.visible\n                    }\n\n                    StyledText {\n                        id: appSeparator\n";
        }
        {
          file = "share/quickshell/dms/Modules/DBar/Widgets/FocusedApp.qml";
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
          # The include banner offers to splice a require of outputs.lua into
          # hyprland.lua, which is a store file here and doesn't need it now.
          # (2.0 shares the banner across tabs; only this instance is hidden.)
          file = "share/quickshell/dms/Modules/Settings/DisplayConfigTab.qml";
          from = "            include: DisplayConfigState.include\n            visibleCondition: DisplayConfigState.hasOutputBackend\n";
          to = "            include: DisplayConfigState.include\n            visibleCondition: false\n";
        }
      ]
      # Not a dispatch fix: the Compositor tab's Hyprland Layout Overrides, the
      # same story as the Displays page. Upstream writes
      # ~/.config/hypr/dms/layout.lua, which hyprland.lua never loads, and then
      # runs `hyprctl reload` — so the page changed nothing, and every
      # regeneration (bar spacing, corner radius, startup) reloaded Hyprland
      # and dropped the session's live state, the Displays page's included.
      # Now only explicit overrides (Custom gaps, the radius and border
      # toggles, resize-on-border) apply, live over `hyprctl eval`; Auto and Off
      # keep hyprland.lua's values. Turning an override off reloads once to
      # restore them. Session-only, like the Displays page. The Xray toggles
      # are hidden: their layer rules can't be undone live, and hyprland.lua
      # owns the dms:* blur rules.
      ++ (
        let
          hs = "share/quickshell/dms/Services/HyprlandService.qml";
          tab = "share/quickshell/dms/Modules/Settings/CompositorLayoutTab.qml";
          # '' strings drop their common indent; the service's members sit at 4.
          indent =
            s:
            lib.concatMapStringsSep "\n" (l: lib.optionalString (l != "") "    ${l}") (lib.splitString "\n" s);
        in
        [
          {
            file = hs;
            from = "    function doGenerateLayoutConfig() {\n";
            to = indent ''
              property var _liveLayoutApplied: ({})

              function applyLayoutLive(requestRevision) {
                  const finish = () => {
                      _layoutAppliedRevision = Math.max(_layoutAppliedRevision, requestRevision);
                      layoutGenerationRunning = false;
                      if (layoutGenerationPending)
                          layoutGenerationAction.schedule();
                  };
                  if (typeof SettingsData === "undefined") {
                      finish();
                      return;
                  }
                  const applied = {};
                  if (SettingsData.hyprlandLayoutGapsOverride >= 0) {
                      applied.gaps_in = SettingsData.hyprlandLayoutGapsOverride;
                      applied.gaps_out = SettingsData.hyprlandLayoutGapsOutOverride >= 0 ? SettingsData.hyprlandLayoutGapsOutOverride : SettingsData.hyprlandLayoutGapsOverride;
                  }
                  if (SettingsData.hyprlandLayoutBorderSize >= 0)
                      applied.border_size = SettingsData.hyprlandLayoutBorderSize;
                  if (SettingsData.hyprlandResizeOnBorder) {
                      applied.resize_on_border = true;
                      // Same default-skip as upstream's generator.
                      if (SettingsData.hyprlandBorderGrabArea !== 15)
                          applied.extend_border_grab_area = SettingsData.hyprlandBorderGrabArea;
                  }
                  if (SettingsData.hyprlandLayoutRadiusOverride >= 0)
                      applied.rounding = SettingsData.hyprlandLayoutRadiusOverride;
                  const dropped = Object.keys(_liveLayoutApplied).some(k => !(k in applied));
                  _liveLayoutApplied = applied;

                  const general = ["gaps_in", "gaps_out", "border_size", "resize_on_border", "extend_border_grab_area"].filter(k => k in applied).map(k => k + " = " + applied[k]);
                  const decoration = "rounding" in applied ? ["rounding = " + applied.rounding] : [];
                  const apply = () => {
                      if (general.length === 0 && decoration.length === 0) {
                          finish();
                          return;
                      }
                      const lua = "hl.config({ general = { " + general.join(", ") + " }, decoration = { " + decoration.join(", ") + " } })";
                      Proc.runCommand("hypr-live-layout", ["hyprctl", "eval", lua], (output, exitCode) => {
                          if (exitCode !== 0)
                              log.warn("Live layout apply failed:", output);
                          finish();
                      });
                  };
                  if (dropped)
                      reloadConfig(() => apply());
                  else
                      apply();
              }

              function doGenerateLayoutConfig() {
            '';
          }
          {
            # Hand over before the layout.lua write; the rest of the function
            # is left in place but no longer reached.
            file = hs;
            from = "        layoutGenerationRunning = true;\n";
            to = "        layoutGenerationRunning = true;\n        applyLayoutLive(requestRevision);\n        return;\n";
          }
          {
            file = tab;
            from = ''title: I18n.tr("Layout overrides")'';
            to = ''title: I18n.tr("Layout overrides") + " (this session)"'';
          }
          {
            file = tab;
            from = "                visible: CompositorService.isHyprland\n                tags: [\"hyprland\", \"xray\", \"blur\", \"background-effect\", \"performance\"]\n";
            to = "                visible: false\n                tags: [\"hyprland\", \"xray\", \"blur\", \"background-effect\", \"performance\"]\n";
          }
          {
            file = tab;
            from = "                visible: CompositorService.isHyprland && !SettingsData.connectedFrameModeActive\n                tags: [\"hyprland\", \"xray\", \"bar\", \"frame\", \"performance\"]\n";
            to = "                visible: false\n                tags: [\"hyprland\", \"xray\", \"bar\", \"frame\", \"performance\"]\n";
          }
          # 2.0's tiling-layout card (dwindle/master/scrolling and their
          # options) and window-opacity slider also only reach layout.lua;
          # hyprland.lua owns both, so they're hidden rather than left inert.
          {
            file = tab;
            from = "            visible: CompositorService.isHyprland\n\n            readonly property var layoutIds:";
            to = "            visible: false\n\n            readonly property var layoutIds:";
          }
          {
            file = tab;
            from = "                settingKey: \"hyprlandWindowOpacity\"\n";
            to = "                settingKey: \"hyprlandWindowOpacity\"\n                visible: false\n";
          }
          # The cursor page (Settings → Theme & Colors → Cursor) had the same
          # write-a-file-nobody-loads-then-reload shape. Its theme and size
          # are Stylix's (the session's XCURSOR_*) and its hide options would
          # be hyprland.lua's, so it follows the layout page: explicit
          # settings apply live — a theme or size through `hyprctl setcursor`,
          # the hide options through `hyprctl eval` — and going back to the
          # defaults restores the session's cursor, reloading only when a hide
          # option is turned off.
          {
            file = hs;
            from = "    function generateCursorConfig() {\n";
            to = indent ''
              property var _liveCursorApplied: ({})
              property string _liveCursorTheme: ""

              function applyCursorLive() {
                  const s = typeof SettingsData !== "undefined" ? SettingsData.cursorSettings : null;
                  const custom = s && s.theme && s.theme !== "System Default" ? s.theme : "";
                  const size = (s && s.size) || 24;
                  const sessionTheme = Quickshell.env("XCURSOR_THEME") || "";
                  const sessionSize = Quickshell.env("XCURSOR_SIZE") || "24";
                  // "" while the session's own cursor is in effect.
                  const themeKey = custom || size !== 24 ? (custom || sessionTheme) + ":" + size : "";
                  const cursor = {};
                  const h = s && s.hyprland;
                  if (h && h.hideOnKeyPress)
                      cursor.hide_on_key_press = true;
                  if (h && h.hideOnTouch)
                      cursor.hide_on_touch = true;
                  if (h && h.inactiveTimeout > 0)
                      cursor.inactive_timeout = h.inactiveTimeout;
                  const dropped = Object.keys(_liveCursorApplied).some(k => !(k in cursor));
                  const themeChanged = themeKey !== _liveCursorTheme;
                  _liveCursorApplied = cursor;
                  _liveCursorTheme = themeKey;

                  const setTheme = () => {
                      const name = themeKey ? (custom || sessionTheme) : sessionTheme;
                      if (name)
                          Proc.runCommand("hyprctl-setcursor", ["hyprctl", "setcursor", name, themeKey ? String(size) : sessionSize], () => {});
                  };
                  const apply = () => {
                      const keys = Object.keys(cursor);
                      if (keys.length === 0)
                          return;
                      const lua = "hl.config({ cursor = { " + keys.map(k => k + " = " + cursor[k]).join(", ") + " } })";
                      Proc.runCommand("hypr-live-cursor", ["hyprctl", "eval", lua], (output, exitCode) => {
                          if (exitCode !== 0)
                              log.warn("Live cursor apply failed:", output);
                      });
                  };
                  if (dropped) {
                      reloadConfig(() => {
                          apply();
                          if (themeKey)
                              setTheme();
                      });
                  } else {
                      apply();
                      if (themeChanged)
                          setTheme();
                  }
              }

              function generateCursorConfig() {
            '';
          }
          {
            # Hand over before the cursor.lua write.
            file = hs;
            from = "        if (!canWriteLuaConfig(\"cursor\"))\n            return;\n";
            to = "        if (!canWriteLuaConfig(\"cursor\"))\n            return;\n        applyCursorLive();\n        return;\n";
          }
        ]
      )
      ++ [
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
      # (Super+/). 2.0 maps the wheel and the XF86 media keys to glyphs
      # itself (KeyUtils.js's KEY_GLYPH_MAP), but prints the mouse buttons
      # raw; they get words, as on the cheat-sheet wallpaper.
      ++ [
        {
          file = "share/quickshell/dms/Common/KeyUtils.js";
          from = "const KEY_GLYPH_MAP = {\n";
          to = "const KEY_GLYPH_MAP = {\n    \"mouse:272\": \"Drag\",\n    \"mouse:273\": \"Right-drag\",\n";
        }
      ]
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
          hdr = "share/quickshell/dms/DCommon/Widgets/DWindowHeader.qml";
        in
        [
          # No dragging it around, double-click maximise or maximise button.
          # 2.0 moved those into DCommon's shared DWindowHeader, so the header
          # gains an opt-in — a `pinned` flag on its controls object — that
          # only the Settings window's controls set.
          {
            file = hdr;
            from = "        enabled: root.controls !== null && !root.compositorDecorated\n";
            to = "        enabled: root.controls !== null && !root.compositorDecorated && !(root.controls?.pinned ?? false)\n";
          }
          {
            file = hdr;
            from = "            visible: !root.compositorDecorated && (root.controls?.canMaximize ?? false)\n";
            to = "            visible: !root.compositorDecorated && (root.controls?.canMaximize ?? false) && !(root.controls?.pinned ?? false)\n";
          }
          {
            file = sm;
            from = "        id: windowControls\n        targetWindow: settingsModal\n";
            to = "        id: windowControls\n        targetWindow: settingsModal\n        readonly property bool pinned: true\n";
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

                  readonly property var ownToplevel: ToplevelManager.toplevels.values.find(t => t.appId === "dev.duxlabs.shell" && t.title === settingsModal.title) ?? null
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
          (
            widget: body:
            let
              # 2.0's system-monitor widgets derive from MonitorPill (itself a
              # BasePill), the rest from BasePill directly.
              base =
                if
                  lib.elem widget [
                    "RamMonitor"
                    "CpuTemperature"
                    "GpuTemperature"
                    "DiskUsage"
                  ]
                then
                  "MonitorPill"
                else
                  "BasePill";
            in
            {
              file = "share/quickshell/dms/Modules/DBar/Widgets/${widget}.qml";
              from = "${base} {\n    id: root\n";
              to =
                "${base} {\n    id: root\n\n"
                + lib.concatMapStringsSep "\n" (l: lib.optionalString (l != "") "    ${l}") (
                  lib.splitString "\n" body
                );
            }
          )
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
      # 2.0's Clock.qml doesn't import Quickshell, which the tooltip's
      # SystemClock comes from; without it the clock, and with it the whole
      # bar, fails to load.
      ++ [
        {
          file = "share/quickshell/dms/Modules/DBar/Widgets/Clock.qml";
          from = "import QtQuick\n";
          to = "import QtQuick\nimport Quickshell\n";
        }
      ]
      # Not a dispatch fix: the lock screen blurs its wallpaper unconditionally
      # (no setting), which smears lockScreenWallpaperPath's logo into a glow.
      # The clock and password field already sit on their own surfaces.
      ++ [
        {
          file = "share/quickshell/dms/Modules/Lock/LockScreenBackground.qml";
          from = "blurEnabled: true\n            blur: Theme.lockScreenBlur";
          to = "blurEnabled: false\n            blur: Theme.lockScreenBlur";
        }
      ]
      # Not a dispatch fix: the Control Center's Bluetooth Scan button could
      # stop working for a whole session. It wrote quickshell's
      # adapter.discovering, whose setter no-ops StartDiscovery whenever its
      # cached Discovering flag is already true and sends StopDiscovery from a
      # D-Bus connection that never started one ("No discovery started"). Once
      # that flag went stale (or another client was scanning), the button showed
      # "Scanning…", found nothing, and a click couldn't recover it; only an
      # outside scan (bluetoothctl) resynced it. Scan through the DMS backend
      # instead, which holds its own BlueZ discovery session, and drive the UI
      # from what we asked for rather than the adapter-global flag. Without the
      # backend it falls back to upstream's behaviour.
      ++ (
        let
          detail = "share/quickshell/dms/Modules/ControlCenter/Details/BluetoothDetail.qml";
          closers = [
            "share/quickshell/dms/Modules/ControlCenter/ControlCenterPopout.qml"
            "share/quickshell/dms/Modules/DIsland/Activities/ControlCenterExpanded.qml"
          ];
        in
        [
          {
            file = "share/quickshell/dms/Services/BluetoothService.qml";
            from = "    readonly property bool discovering: (adapter && adapter.discovering) ?? false\n";
            to = ''
              readonly property bool discovering: (adapter && adapter.discovering) ?? false
              property bool scanRequested: false
              readonly property bool scanning: bluetoothBridgeAvailable ? scanRequested : discovering
              // The backend's discovery session dies with its D-Bus connection.
              onBluetoothBridgeAvailableChanged: if (!bluetoothBridgeAvailable) scanRequested = false

              function setScanning(on) {
                  if (!bluetoothBridgeAvailable) {
                      if (adapter)
                          adapter.discovering = on;
                      return;
                  }
                  scanRequested = on;
                  DMSService.sendRequest(on ? "bluetooth.startDiscovery" : "bluetooth.stopDiscovery", {
                      "adapter": adapter?.dbusPath ?? ""
                  }, response => {
                      // "In progress" / "No discovery started" mean we already have what we asked for.
                      if (!response.error || /progress|No discovery/i.test(response.error))
                          return;
                      log.warn("Failed to " + (on ? "start" : "stop") + " Bluetooth discovery:", response.error);
                      if (on)
                          scanRequested = false;
                  });
              }
            '';
          }
          # The page reads root.discovering everywhere (button, scan-only
          # device list, "Scanning…" placeholder), so rebinding it covers them.
          {
            file = detail;
            from = "readonly property bool discovering: adapter?.discovering ?? false";
            to = "readonly property bool discovering: BluetoothService.scanning";
          }
          {
            file = detail;
            from = "root.adapter.discovering = !root.adapter.discovering;";
            to = "BluetoothService.setScanning(!BluetoothService.scanning);";
          }
        ]
        ++ lib.concatMap (file: [
          {
            inherit file;
            from = "if (BluetoothService.adapter && BluetoothService.adapter.discovering)";
            to = "if (BluetoothService.scanning)";
          }
          {
            inherit file;
            from = "BluetoothService.adapter.discovering = false;";
            to = "BluetoothService.setScanning(false);";
          }
        ]) closers
      )
    )).overrideAttrs
      (old: {
        postInstall = old.postInstall + ''
          chmod u+w "$out/share/quickshell/dms/Widgets"
          install -Dm444 ${../../../config/dms/BarPillTooltip.qml} \
            "$out/share/quickshell/dms/Widgets/BarPillTooltip.qml"
          # CPU + memory + GPU in one pill with usage gauges; replaces the
          # cpuUsage widget in place — see the header of the QML file.
          chmod u+w "$out/share/quickshell/dms/Modules/DBar/Widgets"
          install -Dm444 ${../../../config/dms/BarSystemMonitor.qml} \
            "$out/share/quickshell/dms/Modules/DBar/Widgets/CpuMonitor.qml"
          # Its GPU poll, one shared singleton rather than one per bar.
          chmod u+w "$out/share/quickshell/dms/Services"
          install -Dm444 ${../../../config/dms/GpuStatsService.qml} \
            "$out/share/quickshell/dms/Services/GpuStatsService.qml"
        '';
      });

  # ── Bar layouts ─────────────────────────────────────────────────────────────
  # The main bar, and a trimmed one for portrait outputs. Declaring these means
  # widgets added, removed or reordered in DMS's own GUI revert on the next
  # nixup; per-widget options set there survive (keep() in the activation
  # script below). DMS has no volume/network/bluetooth
  # bar widgets (they live behind its control centre button), and camera + mic
  # fold into one privacyIndicator.
  #
  # DMS's own default barConfigs[0], copied verbatim from dux-shell 2.0.0's
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
  # upstream after 2.0.0 would land undefined on a first-run seed.
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
    innerPadding = 2;
    barInsetPadding = -1;
    barLengthPadding = 0;
    barLengthMode = "full";
    barLengthPercent = 80;
    bottomGap = 0;
    attachToScreenEdge = false;
    followInterfaceStyle = true;
    transparency = 1.0;
    surfaceColor = "default";
    surfaceCustomColor = "#6750A4";
    widgetFollowInterfaceStyle = true;
    widgetTransparency = 1.0;
    squareCorners = false;
    noBackground = false;
    widgetStyle = "pills";
    maximizeWidgetIcons = false;
    maximizeWidgetText = false;
    widgetPadding = 8;
    batteryColorMode = "theme";
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
    autoHideStrict = false;
    autoHideDelay = 250;
    showOnWindowsOpen = false;
    openOnOverview = false;
    visible = true;
    popupGapsAuto = true;
    popupGapsManual = 4;
    maximizeDetection = true;
    useOverlayLayer = false;
    scrollEnabled = true;
    scrollXBehavior = "focusWindow";
    scrollYBehavior = "workspace";
    middleClickAction = "none";
    rightClickAction = "none";
    clickActionFollowMouse = false;
    shadowIntensity = 0;
    shadowOpacity = 60;
    shadowColorMode = "default";
    shadowCustomColor = "#000000";
    shadowDirectionMode = "inherit";
    shadowDirection = "top";
    clickThrough = false;
    hoverPopouts = false;
    hoverPopoutDelay = 150;
  };

  # DMS ships unlabelled dots; number the workspaces instead. A per-widget
  # option since 2.0 (the global showWorkspaceIndex is gone).
  workspaceSwitcher = {
    id = "workspaceSwitcher";
    enabled = true;
    showWorkspaceIndex = true;
  };

  # 2.0's Dynamic Island, the centre of both bars. Hosted in a normal bar it
  # leaves notification popups and OSDs to the bar by default; these hand
  # both to the island instead (IslandBarHost.qml). islandNotificationPopups
  # reads backwards: true keeps DMS's standalone popups, false routes them
  # through the island (SettingsData.dankIslandHandlesNotifications).
  island = {
    id = "island";
    enabled = true;
    islandNotificationPopups = false;
    islandSystemOsd = true;
    # A new notification bubbles out into the full card (title, body,
    # actions) instead of only swapping the pill to "app · summary".
    islandNotificationExpand = true;
    # Critically damped (2·√(stiffness·mass) ≈ 47.3 at DMS's default 560):
    # the stock 37 overshoots and wobbles as it settles. No overshoot, like
    # the Hyprland animations (hyprland.lua).
    islandSpringDamping = 48;
    # The compact face's groups, in order: those before the clock sit left of
    # it, the rest right. DMS's default (SettingsData._islandHomeLayoutDefault)
    # with weather switched on, right of the clock where the weather pill was.
    islandHomeLayout =
      map
        (id: {
          inherit id;
          enabled = true;
        })
        [
          "media"
          "clock"
          "weather"
          "notifications"
          "privacy"
        ]
      ++
        map
          (id: {
            inherit id;
            enabled = false;
          })
          [
            "workspaces"
            "status"
            "volume"
            "brightness"
            "tray"
          ];
  };

  dmsDeclared = {
    barDefault = dmsDefaultBar;
    # Merged into session.json (DMS keeps Night Mode there, not in settings).
    # Night Mode is the night light (gammastep is gone): on, warming to 3500K
    # between sunset and sunrise at the system location (base.nix), 6500K by
    # day. Its Quick Settings tile is patched to override the schedule (the
    # NightModeService patch above); `dms ipc call night disable` is the
    # master off, until the next rebuild switches it back on.
    session = {
      nightModeEnabled = true;
      nightModeAutoEnabled = true;
      nightModeAutoMode = "location";
      nightModeUseIPLocation = false;
      inherit (osConfig.location) latitude longitude;
      nightModeTemperature = 3500;
      nightModeHighTemperature = 6500;
    };
    settings = {
      # Night Mode lifts for fullscreen windows (games, video) and for the
      # colour-critical apps (creative-apps.nix), matched by desktop id.
      nightModeExcludeFullscreen = true;
      nightModeExcludedApps = [
        "gimp"
        "org.kde.krita"
        "org.inkscape.Inkscape"
      ];
      currentThemeName = "custom";
      currentThemeCategory = "custom";
      # As above: DMS resolves and caches the coordinates into its own
      # SessionData once auto-location is on.
      useAutoLocation = true;
      weatherEnabled = true;
      # 2.0's Wellbeing (screen time) logs per-app usage; not wanted.
      wellbeingEnabled = false;
      # Events come from dcal (home/max/calendar.nix). "auto" would also probe
      # for khal, which isn't installed.
      calendarBackend = "dankcal";
      # Exactly what DMS's "Disable Built-in Wallpapers" toggle writes: no screen
      # renders its own wallpaper layer, so a pick can't stack over awww.
      # dms-wallpaper-bridge forwards picks to awww instead.
      screenPreferences.wallpaper = [ ];
      customThemeFile = "${config.xdg.configHome}/dms/gruvbox-material.json";

      # ── Match Hyprland's window styling (config/hypr/hyprland.lua) ──────────
      # Corners follow decoration.rounding (10). 2.0 sizes every radius from
      # one strength instead of a pixel value; 31 is what its own migration
      # makes of the old cornerRadius = 10, and gives 10px window corners.
      radiusStrength = 31;
      # Popouts, control center and the Settings window see-through like kitty.
      # DMS's own blur needs ext-background-effect-v1, which Hyprland 0.55
      # lacks (`dms blur check` → unsupported), so blurEnabled stays off and
      # Hyprland blurs instead: the dms:* layer rule for popouts, and window
      # blur for Settings, which is an ordinary toplevel.
      popupTransparency = 0.85;
      floatingWindowTransparency = 0.85;
      # Popout outline in the active-border yellow at its ee alpha. The blur*
      # names are legacy — DMS draws this border whether or not it blurs. It is
      # fixed at 1px (BlurService.borderWidth), against Hyprland's 2.
      blurBorderEnabled = true;
      blurBorderColor = "custom";
      blurBorderCustomColor = palette.yellow;
      blurBorderOpacity = 0.93;

      # ── Lock screen ─────────────────────────────────────────────────────────
      # DMS is the locker: it answers logind's Lock signal itself, so
      # `loginctl lock-session` (Super+L, hypridle, before sleep) is the one
      # way in. The wallpaper is lock-only; the desktop's stays awww's.
      loginctlLockIntegration = true;
      lockScreenWallpaperPath = cfg.lockWallpaper;
      # The greeter takes its background from this too (productivity.nix).
      lockScreenWallpaperFillMode = "Fill";
      # Finger and password side by side: DMS runs its own fprintd PAM stack
      # in parallel with the password one (/etc/pam.d/dankshell, which has
      # pam_fprintd turned off on fprintd hosts — hosts/framework/default.nix).
      enableFprint = osConfig.services.fprintd.enable;
    };
    # Control Center tiles to strip. Dark Mode would flip DMS off the fixed
    # Gruvbox Material Dark scheme. Filtered out of whatever list DMS has saved rather
    # than replacing it, so tiles added and per-tile tweaks made in its GUI
    # (the brightness slider's DDC device) survive.
    # Running apps goes too: the window list is the launcher's job. (The edit
    # pencil can't be dropped — DMS re-adds it — so it's hidden by a patch.)
    controlCenterDrop = [
      "darkMode"
      "runningApps"
    ];
    # DMS's own default list (dux-shell 2.0.0's SettingsSpec.js), the drops
    # above still in it. Only seeds a settings.json DMS hasn't saved one to:
    # until then it shows this list, and filtering needs something to filter.
    controlCenterDefault =
      let
        tile = id: w: {
          inherit id w;
          enabled = true;
          h = 1;
        };
        small = id: w: tile id w // { small = true; };
      in
      [
        (tile "user" 5)
        (small "settings" 1)
        (small "lock" 1)
        (small "power" 1)
        (tile "brightnessSlider" 4)
        (tile "volumeSlider" 4)
        (tile "wifi" 4)
        (tile "bluetooth" 4)
        (tile "audioOutput" 4)
        (tile "audioInput" 4)
        (tile "darkMode" 2)
        (tile "nightMode" 2)
        (tile "doNotDisturb" 2)
        (tile "idleInhibitor" 2)
        (tile "battery" 4)
        (tile "diskUsage" 4)
        (small "runningApps" 7)
        (small "edit" 1)
      ];
    # Output-picker entries to hide (custom.hm.dms.hiddenOutputs, below).
    inherit (cfg.dms) hiddenOutputs;
    # Plugin tiles appended when missing — only on hosts with the plugin.
    # Once there, their size and other per-tile settings are DMS's to keep.
    # 2.0 lays tiles on a grid of cells: w = 4 is half its default 8 columns,
    # the old width = 50.
    # Idle inhibitor is built in (dropped from the bar for it); Dankscale and
    # Nix Monitor moved here from the bar too.
    controlCenterAdd =
      map
        (id: {
          inherit id;
          enabled = true;
          w = 4;
          h = 1;
        })
        (
          [
            "idleInhibitor"
            "nightMode"
          ]
          ++ map (id: "plugin_${id}") (
            dmsPlugins.barWidget "batteryPlus"
            ++ dmsPlugins.barWidget "dankscale"
            ++ dmsPlugins.barWidget "nixMonitor"
            ++ dmsPlugins.barWidget "quickCapture"
            ++ dmsPlugins.barWidget "keybindsTile"
            ++ dmsPlugins.barWidget "lanMouseTile"
            ++ dmsPlugins.barWidget "dankClight"
          )
        );
    # Tile order, re-applied on every nixup: a drag in DMS's edit mode lasts
    # only until the next rebuild. The listed tiles are gathered into one run,
    # in this order, where the first of them sits; tiles before that (2.0's
    # header row of user, settings, lock and power) stay put, and the rest
    # (tiles added in the GUI) follow the run in their own order. Listed ones a host lacks are skipped.
    controlCenterOrder = [
      "volumeSlider"
      "brightnessSlider"
      "wifi"
      "bluetooth"
      "audioOutput"
      "audioInput"
      "plugin_batteryPlus"
      "idleInhibitor"
      "nightMode"
      "plugin_dankscale"
      "plugin_nixMonitor"
      "plugin_quickCapture"
      "plugin_keybindsTile"
      "plugin_lanMouseTile"
      "plugin_dankClight"
    ];
    bars = {
      # "all" when there is nothing to split, so single-output hosts still show a bar.
      mainScreens = if outputs.hasPortrait then outputs.landscapeOutputs else [ "all" ];
      portraitScreens = outputs.portraitOutputs;
      # Plugin pills (dms-plugins.nix) are each [ ] on a host without that
      # plugin. They fit on the right now that Claude is icon-sized;
      # at full size they ran the right section into the centre.
      left = [
        workspaceSwitcher
        "focusedWindow"
      ];
      # 2.0's Dynamic Island alone in the centre: its compact face is the
      # clock and switches to the playing track or a notification, and it
      # expands in place into the Dash (weather, media, …), so the music,
      # clock and weather pills it replaces would only duplicate it. Kept
      # the only entry so DMS's "index" centeringMode pins it to the exact
      # centre of the bar. It also takes notification popups and OSDs (see
      # `island` above).
      center = [ island ];
      # "cpuUsage" is config/dms/BarSystemMonitor.qml (installed over
      # CpuMonitor.qml above): CPU, memory and GPU in one pill, so cpuTemp,
      # memUsage and gpuTemp aren't listed.
      right = [
        "cpuUsage"
      ]
      ++ dmsPlugins.barWidget "dankKDEConnect"
      ++ dmsPlugins.barWidget "claudeUsage"
      ++ [ "privacyIndicator" ]
      ++ dmsPlugins.barWidget "deviceBatteries"
      ++ dmsPlugins.barWidget "batteryPlus"
      # No notificationButton: the island's notifications group shows the
      # unread count, and the notification center opens in the island.
      ++ [
        "systemTray"
        "controlCenterButton"
      ];
      # DankBarWindow.qml reads barConfig.transparency straight into the
      # background alpha despite the name, so 0 is a fully transparent bar
      # strip. widgetTransparency is the pills' alpha (BasePill.qml), 0.85 to
      # match popupTransparency; the dms:* layer rule in hyprland.lua blurs
      # behind them (its ignore_alpha 0.5 keeps the empty strip unblurred).
      barAlpha = 0;
      widgetAlpha = 0.85;
      pLeft = [ workspaceSwitcher ];
      pCenter = [ island ];
      pRight = [ "controlCenterButton" ];
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
      # polkit-gnome is the session's agent (modules/home/wm/hyprland.nix):
      # it keeps prompting while gaming mode has DMS stopped. Without this,
      # DMS registers its own agent too, and whichever starts second fails.
      Environment = [ "DMS_DISABLE_POLKIT=1" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
in
{
  options.custom.hm = {
    lockWallpaper = lib.mkOption {
      type = lib.types.path;
      description = "DMS lock-screen background. Set per host through the `lockWallpaper` hmArg (default in sharedHmArgs, flake.nix).";
    };

    dms.hiddenOutputs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Audio sink node names to hide from DMS's output picker, unioned into
        its session.json list so devices hidden in the GUI stay hidden. DMS
        lists every Audio/Sink node, so a WirePlumber smart filter's input
        shows up beside the card it feeds; picking it would move the volume
        keys off the card onto the filter. Set by the host that defines the
        filter, next to it.
      '';
    };
  };

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
    ]
    # batteryPlus (dms-plugins.nix, laptops) reads UPower's charge history with
    # `gdbus call`; without gdbus the call fails silently and the chart is empty.
    ++ lib.optional isLaptop pkgs.glib.bin;

    # ── Theming ───────────────────────────────────────────────────────────────
    # DMS reads a user-supplied scheme file that it never writes back to, so
    # unlike its settings.json this can be a plain store symlink rendered from
    # palette.nix.
    xdg.configFile = {
      "dms/gruvbox-material.json".text =
        renderTheme ../../../config/dms/gruvbox-material.json;
    }
    # DMS plugins: one store symlink per plugin directory — see dms-plugins.nix.
    // dmsPlugins.configFiles;

    # ── 2.0's directory rename ───────────────────────────────────────────────
    # DMS 2.0 moved its config/state/cache/data dirs from DankMaterialShell/
    # to dms/, migrating on its first start (rename, then a symlink at the old
    # path). That can't be left to it here: this activation writes into the
    # new dirs first (plugin links, gruvbox-material.json, the settings.json
    # merge below), and DMS's merge of two populated dirs leaves every
    # conflicting file behind in the old one — settings.json included.
    #
    # So move them here, before any link is checked or written, the way DMS
    # would. The moved tree's Home Manager links belong to the old generation
    # and are dropped (the new one relinks what's still declared). The old
    # path must not be a symlink while HM cleans the old generation: its
    # `rmdir -p` of emptied parents would hit it and fail the activation. So
    # the compat symlink DMS leaves for older plugins is only (re)made once
    # the new generation is linked. Drop all this once no machine has a
    # DankMaterialShell dir left.
    home.activation.dmsLegacyDirsMove = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      for base in "${config.xdg.configHome}" "${config.xdg.stateHome}" \
                  "${config.xdg.cacheHome}" "${config.xdg.dataHome}"; do
        old="$base/DankMaterialShell" new="$base/dms"
        if [[ -L "$old" ]]; then
          run rm "$old"
        elif [[ -d "$old" && ! -e "$new" ]]; then
          run mv "$old" "$new"
          run find "$new" -type l -lname '*-home-manager-files/*' -delete
        fi
      done
    '';
    home.activation.dmsLegacyDirsLink = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      for base in "${config.xdg.configHome}" "${config.xdg.stateHome}" \
                  "${config.xdg.cacheHome}" "${config.xdg.dataHome}"; do
        if [[ -d "$base/dms" && ! -e "$base/DankMaterialShell" && ! -L "$base/DankMaterialShell" ]]; then
          run ln -s dms "$base/DankMaterialShell"
        fi
      done
    '';

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
        PathChanged = "${config.xdg.stateHome}/dms/session.json";
        Unit = "dms-wallpaper-bridge.service";
      };
    };

    home.activation.shellSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      apply() {
        local file="$1" decl="$2" prog="$3"
        # The merge ends in output redirects, which HM's `run` can't hold back
        # on a dry run, so a dry run only says what it would do.
        if [[ -v DRY_RUN ]]; then
          echo "would merge $decl into $file"
          return
        fi
        mkdir -p "$(dirname "$file")"
        # DMS loads JSON over its Store property defaults, so seeding an empty
        # object is enough when it has never run.
        [ -s "$file" ] || echo '{}' > "$file"
        ${pkgs.jq}/bin/jq --argjson d "$(cat "$decl")" "$prog" "$file" \
          > "$file.hm-tmp" && mv "$file.hm-tmp" "$file"
      }

      # Stale compiled QML: see `stamp` in dms-plugins.nix. Deleting the cache
      # under a running shell is safe; it recompiles on its next start.
      qmlStamp="${config.xdg.cacheHome}/quickshell/dms-plugins.stamp"
      if [ "$(cat "$qmlStamp" 2>/dev/null)" != "${dmsPlugins.stamp}" ]; then
        run rm -f "${config.xdg.cacheHome}"/quickshell/qmlcache/*.qmlc
        run mkdir -p "$(dirname "$qmlStamp")"
        [[ -v DRY_RUN ]] || echo ${dmsPlugins.stamp} > "$qmlStamp"
      fi

      # DMS plugin_settings.json: which plugins are on, plus a few settings.
      # Same plain merge — each plugin's other keys are whatever it saved.
      apply "${config.xdg.configHome}/dms/plugin_settings.json" \
        ${dmsPluginDecl} \
        '. * $d'

      # DMS session.json: the hidden output devices and Night Mode; the rest
      # is its state.
      apply "${config.xdg.stateHome}/dms/session.json" \
        ${dmsDecl} \
        '.hiddenOutputDeviceNames = ((.hiddenOutputDeviceNames // []) + $d.hiddenOutputs | unique)
         | . * $d.session'

      # DMS: the theme keys merge the same way, but its bars can't — a barConfig
      # carries styling (spacing, transparency, corners…) alongside its widget
      # arrays, and replacing the array wholesale would discard all of it. So
      # rewrite the widget lists in place, and clone bar 0 for the portrait
      # output rather than authoring a second bar from scratch.
      #
      # The widget lists are ours, but since 2.0 each entry can carry that
      # widget's options (clock format, tray layout, …, moved there from
      # global keys by DMS's own migration). keep() takes the declared list
      # and, for each widget already on the bar, its saved entry, with any
      # options declared here merged over it.
      apply "${config.xdg.configHome}/dms/settings.json" \
        ${dmsDecl} \
        'def keep($old; $new):
           $new | map(. as $w
             | ($w | if type == "string" then {id: .} else . end) as $dw
             | ([($old // [])[] | select(type == "object" and .id == $dw.id)] | first) as $e
             | if $e == null then $w
               elif ($w | type) == "string" then $e
               else $e * $w end);
         ($d.settings) as $s
         | . * $s
         # Never run → DMS falls back to its stock list, which has the dropped
         # tiles in it, so seed that list before filtering.
         | .controlCenterWidgets = (
             (.controlCenterWidgets // $d.controlCenterDefault)
             | map(select(.id as $i | $d.controlCenterDrop | index($i) | not)))
         | reduce $d.controlCenterAdd[] as $w (.;
             if any(.controlCenterWidgets[]; .id == $w.id)
             then . else .controlCenterWidgets += [$w] end)
         | .controlCenterWidgets |= (. as $w
             | [ $d.controlCenterOrder[] as $id | $w[] | select(.id == $id) ] as $sorted
             | ([ range(0; $w | length)
                  | select($w[.].id as $i | $d.controlCenterOrder | index($i)) ] | first) as $p
             | if $p == null then $w
               else $w[:$p] + $sorted
                 + [ $w[$p:][] | select(.id as $i | $d.controlCenterOrder | index($i) | not) ]
               end)
         # barConfigs is written by DMS itself, not by the empty-object seed in
         # apply(), so on a machine where DMS has never run there was nothing
         # here to rewrite: the bar came up with stock widgets and DMSs own
         # transparency 1.0, i.e. opaque. Seed the default entry DMS would have
         # written so the overrides below always land on a complete barConfig.
         | if ((.barConfigs | type) == "array") and ((.barConfigs | length) > 0)
           then . else .barConfigs = [ $d.barDefault ] end
         | (.barConfigs[0] |= (
             # 2.0: without these off, the bar and its pills take the popup
             # and theme alphas instead of the two below.
               .followInterfaceStyle       = false
             | .widgetFollowInterfaceStyle = false
             | .transparency       = $d.bars.barAlpha
             | .widgetTransparency = $d.bars.widgetAlpha
             | .screenPreferences = $d.bars.mainScreens
             | .leftWidgets       = keep(.leftWidgets; $d.bars.left)
             | .centerWidgets     = keep(.centerWidgets; $d.bars.center)
             | .rightWidgets      = keep(.rightWidgets; $d.bars.right)))
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
                      | .leftWidgets       = keep(.leftWidgets; $d.bars.pLeft)
                      | .centerWidgets     = keep(.centerWidgets; $d.bars.pCenter)
                      | .rightWidgets      = keep(.rightWidgets; $d.bars.pRight) )
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
