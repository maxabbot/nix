// PowerMenu.qml — Power action panel (bottom-right).
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    anchors { bottom: true; right: true }
    margins { bottom: 44; right: 4 }
    implicitWidth: 220
    implicitHeight: grid.implicitHeight + 32
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        Column {
            id: grid
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
            spacing: 4

            Text {
                text: "Power"
                color: Theme.gray
                font.pixelSize: 11
                font.bold: true
                font.family: Theme.font
                leftPadding: 4
            }

            Repeater {
                model: [
                    { icon: "", label: "Lock",        cmd: "hyprlock" },
                    { icon: "", label: "Sleep",        cmd: "systemctl suspend" },
                    { icon: "", label: "Restart",      cmd: "systemctl reboot" },
                    { icon: "", label: "Shut Down",    cmd: "systemctl poweroff" },
                    { icon: "", label: "Log Out",      cmd: "hyprctl dispatch exit" },
                ]

                delegate: Rectangle {
                    required property var modelData
                    width: grid.width
                    height: 38
                    radius: 8
                    color: area.containsMouse ? Theme.border : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        spacing: 12

                        Text {
                            text: modelData.icon
                            color: Theme.fg
                            font.pixelSize: 14
                            font.family: Theme.font
                        }

                        Text {
                            text: modelData.label
                            color: Theme.fgBright
                            font.pixelSize: 13
                            font.family: Theme.font
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch("exec " + modelData.cmd)
                    }
                }
            }
        }
    }
}
