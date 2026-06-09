// MonitorManager.qml — Display layout viewer + basic controls (full-width, bottom).
// Shows a scaled visual representation of connected monitors using Hyprland.monitors.
// Clicking a monitor selects it; the detail pane lets you change scale.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

PanelWindow {
    id: root

    anchors { bottom: true; left: true; right: true }
    margins.bottom: 44
    implicitHeight: 360
    color: "transparent"

    property var selectedMonitor: null

    Process { id: setMonitor; command: [] }

    // ── Scale factor: fit the total pixel canvas into the preview area ──────────
    readonly property real totalW: {
        var mx = 0
        if (!Hyprland.monitors) return 1920
        for (var i = 0; i < Hyprland.monitors.count; i++) {
            var m = Hyprland.monitors.values[i]
            if (m) mx = Math.max(mx, m.x + m.width)
        }
        return mx > 0 ? mx : 1920
    }
    readonly property real previewScale: Math.min((760 - 32) / totalW, 0.18)

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        ColumnLayout {
            anchors { fill: parent; margins: 16 }
            spacing: 12

            // ── Header ─────────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Monitors"
                    color: Theme.fg
                    font.pixelSize: 14
                    font.bold: true
                    font.family: Theme.font
                    Layout.fillWidth: true
                }
                Text {
                    text: Hyprland.monitors.count + " connected"
                    color: Theme.gray
                    font.pixelSize: 11
                    font.family: Theme.font
                }
            }

            // ── Visual map ─────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 160
                radius: 8
                color: Theme.bgHard
                clip: true

                Item {
                    // Centre the monitor map in the preview area
                    anchors.centerIn: parent
                    width: root.totalW * root.previewScale
                    height: parent.height

                    Repeater {
                        model: Hyprland.monitors

                        delegate: Rectangle {
                            required property var modelData

                            readonly property real logW: modelData.width / (modelData.scale ?? 1)
                            readonly property real logH: modelData.height / (modelData.scale ?? 1)
                            readonly property bool isSelected:
                                root.selectedMonitor?.name === modelData.name

                            x: modelData.x * root.previewScale
                            y: (parent.height / 2) - (logH * root.previewScale / 2) + modelData.y * root.previewScale
                            width:  logW * root.previewScale
                            height: logH * root.previewScale

                            radius: 4
                            color: isSelected ? Theme.accentBg : Theme.bgAlt
                            border.color: isSelected ? Theme.accent : Theme.borderStrong
                            border.width: isSelected ? 2 : 1

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.name
                                    color: isSelected ? Theme.accent : Theme.gray
                                    font.pixelSize: 9
                                    font.bold: isSelected
                                    font.family: Theme.font
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.width + "×" + modelData.height
                                    color: Theme.grayDim
                                    font.pixelSize: 8
                                    font.family: Theme.font
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedMonitor = modelData
                            }
                        }
                    }
                }
            }

            // ── Detail pane (selected monitor) ────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                visible: root.selectedMonitor !== null

                Column {
                    spacing: 4
                    Layout.fillWidth: true

                    Text {
                        text: root.selectedMonitor?.name ?? ""
                        color: Theme.accent
                        font.pixelSize: 13
                        font.bold: true
                        font.family: Theme.font
                    }
                    Text {
                        text: (root.selectedMonitor?.width ?? 0) + "×" +
                              (root.selectedMonitor?.height ?? 0) + " @ " +
                              Math.round(root.selectedMonitor?.refreshRate ?? 0) + " Hz  ·  " +
                              "scale " + (root.selectedMonitor?.scale ?? 1)
                        color: Theme.gray
                        font.pixelSize: 11
                        font.family: Theme.font
                    }
                    Text {
                        text: "Position: " + (root.selectedMonitor?.x ?? 0) + ", " + (root.selectedMonitor?.y ?? 0)
                        color: Theme.grayDim
                        font.pixelSize: 10
                        font.family: Theme.font
                    }
                }

                // Scale picker (quick presets)
                Column {
                    spacing: 6

                    Text {
                        text: "Scale"
                        color: Theme.gray
                        font.pixelSize: 11
                        font.family: Theme.font
                    }

                    RowLayout {
                        spacing: 4

                        Repeater {
                            model: ["1", "1.25", "1.5", "2"]

                            delegate: Rectangle {
                                required property string modelData
                                width: 46; height: 26; radius: 6
                                color: {
                                    var cur = (root.selectedMonitor?.scale ?? 1).toString()
                                    return cur === modelData
                                        ? Theme.accentBg
                                        : (scaleArea.containsMouse ? Theme.border : Theme.bgAlt)
                                }
                                Behavior on color { ColorAnimation { duration: 80 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "×"
                                    color: Theme.fg
                                    font.pixelSize: 11
                                    font.family: Theme.font
                                }

                                MouseArea {
                                    id: scaleArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!root.selectedMonitor) return
                                        var m = root.selectedMonitor
                                        setMonitor.command = [
                                            "hyprctl", "keyword", "monitor",
                                            m.name + "," +
                                            m.width + "x" + m.height + "@" +
                                            Math.round(m.refreshRate) + "," +
                                            m.x + "x" + m.y + "," + modelData
                                        ]
                                        setMonitor.running = true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Placeholder when nothing selected
            Text {
                visible: root.selectedMonitor === null
                text: "Click a monitor above to select it"
                color: Theme.borderStrong
                font.pixelSize: 12
                font.family: Theme.font
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
