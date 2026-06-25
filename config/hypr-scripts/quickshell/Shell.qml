// Shell.qml — Quickshell entry point.
// Launch: quickshell -p ~/.config/hypr/scripts/quickshell/Shell.qml
//
// Manages:
//   • All pop-up panels (visibility gated by activePanel)
//   • Tabbed Settings panel (Control/Audio/Monitors/Wallpaper/System/Nix pages)
//   • Notification server (replaces swaync — D-Bus org.freedesktop.Notifications)
//   • IPC from qs_manager.sh: quickshell ipc call main handleCommand <action> <target> <subtarget>
//   • Waybar state bridge: notification count + rebuild flag written to
//     $XDG_RUNTIME_DIR/quickshell/, waybar custom modules refreshed via RTMIN+8

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import QtQuick

ShellRoot {
    id: root

    // ── Global state ───────────────────────────────────────────────────────────
    property string activePanel:    ""
    property string settingsTab:    "control"
    property bool   dndEnabled:     false
    property bool   rebuildRunning: false

    readonly property var settingsTabs: ["control", "network", "bluetooth", "audio", "monitors", "wallpaper", "theme", "keyboard", "input", "battery", "disks", "sysinfo", "nix"]

    // Click-off dismissal grace: a Waybar button press first breaks the focus
    // grab (closing the panel), then the button's toggle fires on release —
    // without this it would instantly reopen. Key is "settings:<tab>" or the
    // panel name.
    property string dismissedPanel: ""
    property double dismissedAt:    0

    function justDismissed(key) {
        return key === dismissedPanel && (Date.now() - dismissedAt) < 350
    }

    // ── IPC handler (qs_manager.sh routes here) ────────────────────────────────
    // target "settings" takes a tab name as subtarget; the former standalone
    // panel targets (control/audio/…) are mapped to Settings tabs so old
    // callers and keybinds keep working. Unknown subtargets (e.g. the legacy
    // "top"/"bottom" edge values) are ignored.
    IpcHandler {
        target: "main"
        function handleCommand(action: string, target: string, subtarget: string): void {
            if (action === "close") { root.activePanel = ""; return }
            if (action === "osd") { root.osd(target); return }

            var tgt = target
            var tab = ""
            if (target === "settings") {
                tab = root.settingsTabs.indexOf(subtarget) >= 0 ? subtarget : ""
            } else if (root.settingsTabs.indexOf(target) >= 0) {
                tgt = "settings"
                tab = target
            }

            if (tgt === "settings") {
                if (action === "toggle" && root.activePanel === "settings"
                        && (tab === "" || tab === root.settingsTab)) {
                    root.activePanel = ""   // same tab re-clicked → close
                } else if (action === "toggle" && root.activePanel !== "settings"
                        && root.justDismissed("settings:" + (tab !== "" ? tab : root.settingsTab))) {
                    // the click that dismissed it was this button — stay closed
                } else {
                    if (tab !== "") root.settingsTab = tab
                    root.activePanel = "settings"
                }
            } else if (action === "toggle") {
                if (root.activePanel === tgt) root.activePanel = ""
                else if (!root.justDismissed(tgt)) root.activePanel = tgt
            } else if (action === "open") {
                root.activePanel = tgt
            }
        }
    }

    // ── On-screen display (volume / brightness) ────────────────────────────────
    // Volume is observed passively from PipeWire (any change — keybind or panel —
    // flashes the OSD). Brightness has no passive signal, so it's push-triggered
    // by the `osd brightness` IPC call from the brightness keybinds.
    property string osdKind:  ""    // "volume" | "brightness" | ""
    property real   osdLevel: 0     // 0..1
    property bool   osdMuted:  false
    property bool   osdReady:  false // suppress the initial volume-bind event on startup

    Timer { id: osdHideTimer;  interval: 1600; onTriggered: root.osdKind = "" }
    Timer { id: osdReadyTimer; interval: 1000; running: true; onTriggered: root.osdReady = true }

    function showOsd(kind, level, muted) {
        root.osdKind  = kind
        root.osdLevel = Math.max(0, Math.min(1, level))
        root.osdMuted = muted === true
        osdHideTimer.restart()
    }

    // Entry point for the `osd <kind>` IPC action.
    function osd(kind) {
        if (kind === "brightness") {
            brightnessProbe.running = true
        } else if (kind === "volume" && Pipewire.defaultAudioSink?.audio) {
            showOsd("volume", Pipewire.defaultAudioSink.audio.volume,
                    Pipewire.defaultAudioSink.audio.muted)
        }
    }

    // Keep the default sink bound so its volume/mute changes fire globally.
    PwObjectTracker { objects: [Pipewire.defaultAudioSink].filter(n => n) }

    Connections {
        target: Pipewire.defaultAudioSink?.audio ?? null
        function onVolumeChanged() {
            if (root.osdReady) root.showOsd("volume",
                Pipewire.defaultAudioSink.audio.volume, Pipewire.defaultAudioSink.audio.muted)
        }
        function onMutedChanged() {
            if (root.osdReady) root.showOsd("volume",
                Pipewire.defaultAudioSink.audio.volume, Pipewire.defaultAudioSink.audio.muted)
        }
    }

    Process {
        id: brightnessProbe
        command: ["bash", "-c", "brightnessctl -m | awk -F, '{print $4}' | tr -d '%'"]
        stdout: SplitParser {
            onRead: (line) => {
                var p = parseInt(line.trim())
                if (!isNaN(p)) root.showOsd("brightness", p / 100, false)
            }
        }
    }

    Osd {
        kind:  root.osdKind
        level: root.osdLevel
        muted: root.osdMuted
    }

    // ── Notification server ────────────────────────────────────────────────────
    // Registers as org.freedesktop.Notifications on the session D-Bus.
    // Remove swaync from autostart — only one daemon may run at a time.
    NotificationServer {
        id: notifServer
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        imageSupported: true
        persistenceSupported: true

        // Quickshell discards every incoming notification unless the handler
        // marks it tracked — without this, trackedNotifications stays empty and
        // no toast ever appears.
        onNotification: notification => notification.tracked = true
    }

    // ── Waybar state bridge ────────────────────────────────────────────────────
    // Event-driven: write state files and poke waybar's custom modules
    // (custom/notifications, custom/rebuild use "signal": 8, "interval": "once").
    readonly property int notifCount: notifServer.trackedNotifications?.values.length ?? 0

    function syncWaybar() {
        Quickshell.execDetached(["bash", "-c",
            "d=\"${XDG_RUNTIME_DIR:-/tmp}/quickshell\"; mkdir -p \"$d\"; " +
            "printf '%d' " + notifCount + " > \"$d/notif-count\"; " +
            "printf '%s' '" + (rebuildRunning ? "1" : "") + "' > \"$d/rebuild\"; " +
            "pkill -RTMIN+8 waybar"])
    }
    onNotifCountChanged: syncWaybar()
    onRebuildRunningChanged: syncWaybar()
    Component.onCompleted: syncWaybar()   // reset stale files on (re)start

    // ── Notification popup (top-right, transient) ──────────────────────────────
    PanelWindow {
        anchors { top: true; right: true }
        margins { top: 8; right: 8 }
        implicitWidth: 390
        implicitHeight: toastCol.implicitHeight + 16
        exclusiveZone: 0  // don't push tiled windows
        color: "transparent"
        visible: root.notifCount > 0 && !root.dndEnabled

        Column {
            id: toastCol
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
            spacing: 6

            Repeater {
                model: notifServer.trackedNotifications
                delegate: NotificationToast {
                    required property var modelData
                    notification: modelData
                    width: 374
                }
            }
        }
    }

    // ── Panels ─────────────────────────────────────────────────────────────────
    NotificationCenter {
        id: notifCenter
        visible: root.activePanel === "notifications"
        model: notifServer.trackedNotifications
        onCloseRequested: root.activePanel = ""
    }

    Settings {
        id: settingsPanel
        visible: root.activePanel === "settings"
        currentTab: root.settingsTab
        dndEnabled: root.dndEnabled
        onCloseRequested: root.activePanel = ""
        onDndToggled: root.dndEnabled = !root.dndEnabled
        onRebuildStarted:        root.rebuildRunning = true
        onRebuildFinished: (ok) => root.rebuildRunning = false
        onCurrentTabChanged: root.settingsTab = currentTab   // sidebar clicks update shared state
    }

    KeybindCheatSheet {
        id: keybindSheet
        visible: root.activePanel === "keybinds"
        onCloseRequested: root.activePanel = ""
    }

    // Click-off dismissal for the dropdown panels: while one is open it holds
    // a focus grab; any click outside clears the grab and closes it.
    HyprlandFocusGrab {
        active: root.activePanel === "notifications"
             || root.activePanel === "settings"
             || root.activePanel === "keybinds"
        windows: [ notifCenter, settingsPanel, keybindSheet ]
        onCleared: {
            if (root.activePanel === "") return
            root.dismissedPanel = root.activePanel === "settings"
                ? "settings:" + root.settingsTab : root.activePanel
            root.dismissedAt = Date.now()
            root.activePanel = ""
        }
    }

    PowerMenu {
        visible: root.activePanel === "power"
        onCloseRequested: root.activePanel = ""
    }

    ScreenshotOverlay {
        visible: root.activePanel === "screenshot"
        onCloseRequested: root.activePanel = ""
    }

    ClipboardPanel {
        visible: root.activePanel === "clipboard"
        onCloseRequested: root.activePanel = ""
    }
}
