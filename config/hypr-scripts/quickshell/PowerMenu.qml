// PowerMenu.qml — Fullscreen session/power overlay (replaces wlogout).
// Dimmed backdrop with a row of large action tiles. Esc or a click outside a
// tile dismisses. Each action closes the overlay first, then runs detached so
// the command (e.g. hyprlock) isn't tied to this window's lifecycle.
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    signal closeRequested()

    anchors { top: true; left: true; right: true; bottom: true }
    exclusiveZone: -1
    color: "transparent"

    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function run(cmd) {
        root.closeRequested()
        Quickshell.execDetached(["bash", "-c", cmd])
    }

    // Esc to cancel
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closeRequested()
    }

    // Dimmer — click outside the tiles to dismiss
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 28

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18

            Repeater {
                model: [
                    { icon: "󰌾", label: "Lock",     cmd: "hyprlock" },
                    { icon: "󰤄", label: "Suspend",  cmd: "systemctl suspend" },
                    { icon: "󰍃", label: "Logout",   cmd: "uwsm stop" },
                    { icon: "󰜉", label: "Reboot",   cmd: "systemctl reboot" },
                    { icon: "󰐥", label: "Shutdown", cmd: "systemctl poweroff" },
                ]

                delegate: Rectangle {
                    required property var modelData

                    width: 132
                    height: 132
                    radius: 16
                    color: area.containsMouse ? Theme.accentBg : Theme.bgAlt
                    border.color: area.containsMouse ? Theme.accent : Theme.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.icon
                            color: area.containsMouse ? Theme.accent : Theme.fg
                            font.pixelSize: 40
                            font.family: Theme.font
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.label
                            color: Theme.fgBright
                            font.pixelSize: 13
                            font.family: Theme.font
                        }
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.run(modelData.cmd)
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Esc to cancel"
            color: Theme.gray
            font.pixelSize: 12
            font.family: Theme.font
        }
    }
}
