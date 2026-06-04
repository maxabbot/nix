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
    color: Qt.rgba(40/255, 40/255, 40/255, 0.92)

    // Hairline top border
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        color: "#3c3836"
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 8; rightMargin: 8
            topMargin: 1  // clear the border
        }
        spacing: 4

        // ── Left: launcher + workspaces ────────────────────────────────────────
        BarButton {
            icon: ""
            tooltip: "App Launcher"
            active: root.activePanel === "launcher"
            onClicked: root.panelToggled("launcher")
        }

        Workspaces { Layout.alignment: Qt.AlignVCenter }

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

        BarButton {
            icon: "󰅇"
            tooltip: "Clipboard"
            active: root.activePanel === "clipboard"
            onClicked: root.panelToggled("clipboard")
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
                color: "#7daea3"; font.pixelSize: 14
                font.family: "JetBrainsMono Nerd Font"
            }

            Timer {
                running: rebuildSpinner.visible
                interval: 80; repeat: true
                onTriggered: rebuildSpinner.idx = (rebuildSpinner.idx + 1) % rebuildSpinner.chars.length
            }
        }

        BarButton {
            icon: "󱄅"
            tooltip: "Nix"
            active: root.activePanel === "nix"
            onClicked: root.panelToggled("nix")
        }

        // Separator
        Rectangle {
            width: 1; height: 20
            color: "#3c3836"
            Layout.alignment: Qt.AlignVCenter
        }

        BarButton {
            icon: ""
            tooltip: "Monitors"
            active: root.activePanel === "monitors"
            onClicked: root.panelToggled("monitors")
        }

        BarButton {
            icon: ""
            tooltip: "Wallpapers"
            active: root.activePanel === "wallpaper"
            onClicked: root.panelToggled("wallpaper")
        }

        // Separator
        Rectangle {
            width: 1; height: 20
            color: "#3c3836"
            Layout.alignment: Qt.AlignVCenter
        }

        BarButton {
            icon: ""
            tooltip: "Notifications"
            active: root.activePanel === "notifications"
            badge: root.notifCount
            onClicked: root.panelToggled("notifications")
        }

        BarButton {
            icon: ""
            tooltip: "Control Center"
            active: root.activePanel === "control"
            onClicked: root.panelToggled("control")
        }

        BarButton {
            icon: ""
            tooltip: "Audio"
            active: root.activePanel === "audio"
            onClicked: root.panelToggled("audio")
        }

        BarButton {
            icon: ""
            tooltip: "Power"
            active: root.activePanel === "power"
            onClicked: root.panelToggled("power")
        }
    }
}
