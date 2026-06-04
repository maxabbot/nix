// Shell.qml — Quickshell entry point.
// Launch: quickshell -p ~/.config/hypr/scripts/quickshell/Shell.qml
//
// Manages:
//   • Bottom bar (one per screen via Variants)
//   • All pop-up panels (visibility gated by activePanel)
//   • Notification server (replaces swaync — D-Bus org.freedesktop.Notifications)
//   • IPC from qs_manager.sh: quickshell ipc call main handleCommand <action> <target> <subtarget>

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

ShellRoot {
    id: root

    // ── Global state ───────────────────────────────────────────────────────────
    property string activePanel:    ""
    property bool   dndEnabled:     false
    property bool   rebuildRunning: false

    function togglePanel(name) {
        activePanel = (activePanel === name) ? "" : name
    }

    // ── IPC handler (qs_manager.sh routes here) ────────────────────────────────
    IpcHandler {
        target: "main"
        function handleCommand(action, target, subtarget) {
            if (action === "close")        root.activePanel = ""
            else if (action === "toggle")  root.togglePanel(target)
            else if (action === "open")    root.activePanel = target
        }
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
    }

    // ── Notification popup (top-right, transient) ──────────────────────────────
    PanelWindow {
        anchors { top: true; right: true }
        margins { top: 8; right: 8 }
        width: 390
        height: toastCol.implicitHeight + 16
        exclusiveZone: 0  // don't push tiled windows
        color: "transparent"
        visible: notifServer.notifications.count > 0 && !root.dndEnabled

        Column {
            id: toastCol
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
            spacing: 6

            Repeater {
                model: notifServer.notifications
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
        visible: root.activePanel === "notifications"
        model: notifServer.notifications
    }

    AppLauncher {
        visible: root.activePanel === "launcher"
    }

    PowerMenu {
        visible: root.activePanel === "power"
    }

    ControlCenter {
        visible: root.activePanel === "control"
        dndEnabled: root.dndEnabled
        onDndToggled: root.dndEnabled = !root.dndEnabled
    }

    AudioMixer {
        visible: root.activePanel === "audio"
    }

    MonitorManager {
        visible: root.activePanel === "monitors"
    }

    WallpaperPicker {
        visible: root.activePanel === "wallpaper"
    }

    KeybindCheatSheet {
        visible: root.activePanel === "keybinds"
    }

    ClipboardManager {
        visible: root.activePanel === "clipboard"
    }

    NixPanel {
        visible: root.activePanel === "nix"
        onRebuildStarted:       root.rebuildRunning = true
        onRebuildFinished: (ok) => root.rebuildRunning = false
    }

    // ── Bottom bar (one per screen) ─────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors { left: true; right: true; bottom: true }
            height: 40
            exclusiveZone: height
            color: "transparent"

            Bar {
                anchors.fill: parent
                activePanel:    root.activePanel
                notifCount:     notifServer.notifications.count
                rebuildRunning: root.rebuildRunning
                onPanelToggled: (name) => root.togglePanel(name)
            }
        }
    }
}
