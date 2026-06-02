// Shell.qml — Quickshell entry point.
// Launch: quickshell -p ~/.config/hypr/scripts/quickshell/Shell.qml
//
// Spawns one bottom bar per connected screen.
// Receives IPC from qs_manager.sh via: quickshell ipc call main handleCommand ...

import Quickshell
import QtQuick

ShellRoot {
    id: root

    // ── IPC handler ───────────────────────────────────────────────────────────
    // qs_manager.sh routes: quickshell -p Shell.qml ipc call main handleCommand <action> <target> <subtarget>
    IpcHandler {
        target: "main"

        function handleCommand(action: string, target: string, subtarget: string): void {
            if (action === "close") {
                // TODO: close named panels as they are added
            } else if (action === "open" || action === "toggle") {
                // TODO: dispatch to network / wallpaper / guide panels
            }
        }
    }

    // ── One bottom bar per screen ─────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                left: true
                right: true
                bottom: true
            }

            height: 40
            // Reserve the bar height so windows don't go under it.
            exclusiveZone: height
            color: "transparent"

            Bar {
                anchors.fill: parent
            }
        }
    }
}
