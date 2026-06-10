// Bar.qml — Bottom bar content.
// Parent (Shell.qml) sets activePanel, notifCount, rebuildRunning; bar emits panelToggled(name).
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string activePanel:    ""
    property int    notifCount:     0
    property bool   rebuildRunning: false

    signal panelToggled(string name)

    // bg0 at 92% opacity — matches Waybar
    color: Theme.barBg

    // Hairline top border
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        color: Theme.border
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 8; rightMargin: 8
            topMargin: 1  // clear the border
        }
        spacing: 4

        // ── Centre: media player ───────────────────────────────────────────────
        Item { Layout.fillWidth: true }

        MediaPlayer {
            Layout.alignment: Qt.AlignVCenter
            visible: Mpris.players.count > 0
        }

        Item { Layout.fillWidth: true }

        // ── Right: system tray buttons ─────────────────────────────────────────

        BarButton {
            icon: "󰌌"
            tooltip: "Keybind Sheet"
            active: root.activePanel === "keybinds"
            onClicked: root.panelToggled("keybinds")
        }

        // Rebuild spinner — visible during nh os/home switch
        Item {
            id: rebuildSpinner
            visible: root.rebuildRunning
            width: 24; height: 34
            Layout.alignment: Qt.AlignVCenter

            property int idx: 0
            property var chars: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

            Text {
                anchors.centerIn: parent
                text: rebuildSpinner.chars[rebuildSpinner.idx]
                color: Theme.accent; font.pixelSize: 14
                font.family: Theme.font
            }

            Timer {
                running: rebuildSpinner.visible
                interval: 80; repeat: true
                onTriggered: rebuildSpinner.idx = (rebuildSpinner.idx + 1) % rebuildSpinner.chars.length
            }
        }

        BarButton {
            icon: "󰂚"
            tooltip: "Notifications"
            active: root.activePanel === "notifications"
            badge: root.notifCount
            onClicked: root.panelToggled("notifications")
        }
    }
}
