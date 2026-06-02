// Bar.qml — Bottom bar content.
// Gruvbox Material Dark palette throughout.

import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Rectangle {
    // bg0 at 92% opacity — matches Waybar's background
    color: Qt.rgba(40/255, 40/255, 40/255, 0.92)

    // Hairline top border so the bar reads as a separate surface
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: "#3c3836"
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 8
            rightMargin: 8
            topMargin: 1  // clear the border
        }
        spacing: 0

        // ── Workspace switcher ────────────────────────────────────────────────
        Workspaces {
            Layout.alignment: Qt.AlignVCenter
        }

        // ── Spacer ────────────────────────────────────────────────────────────
        Item { Layout.fillWidth: true }

        // Placeholder — future panels (network, volume, clock) go here
    }
}
