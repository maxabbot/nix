// Workspaces.qml — Clickable workspace dots for the bottom bar.
//
// Shows one dot per live workspace (workspaces with at least one window, plus
// the active one). Clicking switches to that workspace.
//
// Active workspace is determined by the focused monitor's active workspace —
// adequate for a single-monitor workflow; future improvement is to compare
// against the bar's own screen's active workspace using HyprlandMonitor.

import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

RowLayout {
    spacing: 6

    Repeater {
        // Hyprland.workspaces is an ObjectModel<HyprlandWorkspace>.
        // Workspaces appear/disappear as windows open/close.
        model: Hyprland.workspaces

        delegate: Rectangle {
            required property var modelData  // HyprlandWorkspace

            readonly property bool isActive:
                (Hyprland.focusedMonitor?.activeWorkspace?.id ?? -1) === modelData.id

            width: 26
            height: 26
            radius: 13
            color: isActive ? "#7daea3" : "#3c3836"

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            // Workspace number
            Text {
                anchors.centerIn: parent
                text: modelData.id
                color: parent.isActive ? "#1d2021" : "#928374"
                font.pixelSize: 10
                font.weight: parent.isActive ? Font.Bold : Font.Normal
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + modelData.id)
            }
        }
    }
}
