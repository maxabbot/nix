// ScreenshotOverlay.qml — Screenshot / recording mode picker.
// Opened via: qs_manager.sh toggle screenshot
// On tile click: signals Shell.qml to close this panel, waits 150 ms for the
// compositor to clear the layer surface, then runs the chosen screenshot.sh command.
import Quickshell
import Quickshell.Io
import QtQuick

PanelWindow {
    id: root

    signal closeRequested()

    anchors { bottom: true }
    margins { bottom: Theme.panelGap }
    implicitWidth: 340
    implicitHeight: col.implicitHeight + 32
    color: "transparent"

    property string pendingCmd: ""

    Timer {
        id: execTimer
        interval: 150
        onTriggered: {
            if (root.pendingCmd !== "") {
                proc.command = ["bash", "-c", root.pendingCmd]
                proc.running = true
                root.pendingCmd = ""
            }
        }
    }

    Process { id: proc }

    function launch(cmd) {
        root.pendingCmd = cmd
        root.closeRequested()
        execTimer.start()
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPanel
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        Column {
            id: col
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
            spacing: 12

            Text {
                text: "Screenshot"
                color: Theme.fg
                font.pixelSize: 14
                font.bold: true
                font.family: Theme.font
            }

            Grid {
                id: tileGrid
                width: parent.width
                columns: 3
                spacing: 8

                Repeater {
                    model: [
                        { icon: "󰹸", label: "Region",
                          cmd: 'GEOM=$(slurp) && bash "$HOME"/.config/hypr/scripts/screenshot.sh --geometry "$GEOM"' },
                        { icon: "󰏫", label: "Annotate",
                          cmd: 'GEOM=$(slurp) && bash "$HOME"/.config/hypr/scripts/screenshot.sh --edit --geometry "$GEOM"' },
                        { icon: "󰍹", label: "Fullscreen",
                          cmd: 'bash "$HOME"/.config/hypr/scripts/screenshot.sh --full' },
                        { icon: "󰖯", label: "Window",
                          cmd: 'bash "$HOME"/.config/hypr/scripts/screenshot.sh --window' },
                        { icon: "⏺", label: "Record",
                          cmd: 'bash "$HOME"/.config/hypr/scripts/screenshot.sh --record --full' },
                        { icon: "󰐱", label: "Scan QR",
                          cmd: 'bash "$HOME"/.config/hypr/scripts/screenshot.sh --scan-qr-notify' },
                    ]

                    delegate: Rectangle {
                        required property var modelData

                        width: (tileGrid.width - 16) / 3
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
                            onClicked: root.launch(modelData.cmd)
                        }
                    }
                }
            }

            Item { height: 4 }
        }
    }
}
