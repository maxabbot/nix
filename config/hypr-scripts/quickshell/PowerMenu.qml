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

    // Session actions, shared between the tile Repeater and keyboard navigation.
    readonly property var actions: [
        { icon: "󰌾", label: "Lock",     cmd: "hyprlock" },
        { icon: "󰤄", label: "Suspend",  cmd: "systemctl suspend" },
        { icon: "󰍃", label: "Logout",   cmd: "uwsm stop" },
        { icon: "󰜉", label: "Reboot",   cmd: "systemctl reboot" },
        { icon: "󰐥", label: "Shutdown", cmd: "systemctl poweroff" },
    ]

    // Highlighted tile for arrow-key navigation; -1 = none (mouse-only) until an
    // arrow key is pressed. Reset each time the overlay opens.
    property int selectedIndex: -1
    onVisibleChanged: if (visible) selectedIndex = -1

    function run(cmd) {
        root.closeRequested()
        Quickshell.execDetached(["bash", "-c", cmd])
    }

    // Keyboard: ←/→ move the highlight, Enter fires it, Esc cancels.
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closeRequested()
        Keys.onLeftPressed:  root.selectedIndex = (root.selectedIndex <= 0 ? root.actions.length - 1 : root.selectedIndex - 1)
        Keys.onRightPressed: root.selectedIndex = (root.selectedIndex < 0 ? 0 : (root.selectedIndex + 1) % root.actions.length)
        Keys.onReturnPressed: if (root.selectedIndex >= 0) root.run(root.actions[root.selectedIndex].cmd)
        Keys.onEnterPressed:  if (root.selectedIndex >= 0) root.run(root.actions[root.selectedIndex].cmd)
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
                model: root.actions

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    // Highlighted by hover or by the keyboard selection.
                    readonly property bool active: area.containsMouse || index === root.selectedIndex

                    width: 132
                    height: 132
                    radius: 16
                    color: active ? Theme.accentBg : Theme.bgAlt
                    border.color: active ? Theme.accent : Theme.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.icon
                            color: active ? Theme.accent : Theme.fg
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
            text: "← →  select  ·  Enter  confirm  ·  Esc  cancel"
            color: Theme.gray
            font.pixelSize: 12
            font.family: Theme.font
        }
    }
}
