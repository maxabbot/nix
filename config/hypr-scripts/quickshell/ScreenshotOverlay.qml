// ScreenshotOverlay.qml — Fullscreen screenshot mode picker.
// Tile clicks use Hyprland.dispatch() which routes through Hyprland IPC and is
// independent of this component's lifecycle. Hyprland evaluates dispatch requests
// as Lua, so the request must use hl.dsp syntax (hl.dsp.exec_cmd(...)), not the
// classic "exec ..." string.
// The launched script closes the overlay, waits 200 ms, then runs the command.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    signal closeRequested()

    anchors { top: true; left: true; right: true; bottom: true }
    exclusiveZone: -1
    color: "transparent"

    // Grab the keyboard while visible so Escape can dismiss the overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closeRequested()
    }

    // ── Dimmer — click outside toolbar to dismiss ───────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    // ── Top toolbar ─────────────────────────────────────────────────────────
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 96
        color: Theme.bg

        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: Theme.border
        }

        Row {
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: [
                    { icon: "󰹸", label: "Region",     mode: "region" },
                    { icon: "󰏫", label: "Annotate",   mode: "annotate" },
                    { icon: "󰍹", label: "Fullscreen",  mode: "full" },
                    { icon: "󰖯", label: "Window",      mode: "window" },
                    { icon: "⏺", label: "Record",      mode: "record" },
                    { icon: "󰐱", label: "Scan QR",     mode: "qr" },
                ]

                delegate: Rectangle {
                    required property var modelData

                    width: 100
                    height: 72
                    radius: Theme.radiusButton
                    color: area.containsMouse ? Theme.borderStrong : Theme.bgAlt
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.icon
                            color: Theme.accent
                            font.pixelSize: 20
                            font.family: Theme.font
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            color: Theme.fgBright
                            font.pixelSize: 11
                            font.family: Theme.font
                        }
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch('hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/screenshot-launch.sh ' + modelData.mode + '")')
                    }
                }
            }
        }
    }
}
