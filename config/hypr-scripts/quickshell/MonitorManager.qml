// MonitorManager.qml — Display layout page (embedded in Settings.qml — no window chrome).
// Shows a scaled visual representation of connected monitors using Hyprland.monitors.
// Clicking a monitor selects it; the detail pane lets you change scale.
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var selectedMonitor: null

    // Mode list for the selected monitor, parsed from hyprctl availableModes.
    property var    modes:      []   // [{res, w, h, refresh, label}]
    property string selRes:     ""   // "2560x1440"
    property real   selRefresh: 0

    Process { id: setMonitor; command: [] }

    onSelectedMonitorChanged: {
        if (selectedMonitor) {
            selRes = selectedMonitor.width + "x" + selectedMonitor.height
            selRefresh = selectedMonitor.refreshRate
            modes = []
            fetchModes.command = ["bash", "-c",
                "hyprctl monitors -j | jq -r --arg n \"$1\" '.[]|select(.name==$n)|.availableModes[]'",
                "bash", selectedMonitor.name]
            fetchModes.running = true
        } else {
            modes = []
        }
    }

    // availableModes look like "3840x2160@60.00Hz".
    Process {
        id: fetchModes
        command: []
        property var accum: []
        stdout: SplitParser {
            onRead: (line) => {
                var s = line.trim()
                if (s === "") return
                var at = s.split("@")
                if (at.length < 2) return
                var wh = at[0].split("x")
                var refresh = parseFloat(at[1].replace("Hz", ""))
                fetchModes.accum.push({
                    res: at[0], w: parseInt(wh[0]) || 0, h: parseInt(wh[1]) || 0,
                    refresh: refresh, label: String(Math.round(refresh))
                })
            }
        }
        onRunningChanged: if (!running) { root.modes = accum; accum = [] }
    }

    // Unique resolutions (largest first) and refresh rates for the chosen one.
    readonly property var resolutions: {
        var seen = ({}), out = []
        for (var i = 0; i < root.modes.length; i++) {
            var m = root.modes[i]
            if (!seen[m.res]) { seen[m.res] = true; out.push(m) }
        }
        out.sort((a, b) => (b.w * b.h) - (a.w * a.h))
        return out
    }
    readonly property var refreshesForSel:
        root.modes.filter(m => m.res === root.selRes).sort((a, b) => b.refresh - a.refresh)

    // Apply res@refresh (+ scale) to the selected monitor, keeping its position.
    function applyMode(res, refresh, scale) {
        if (!root.selectedMonitor) return
        var m = root.selectedMonitor
        setMonitor.command = [
            "hyprctl", "keyword", "monitor",
            m.name + "," + res + "@" + refresh + "," +
            m.x + "x" + m.y + "," + (scale ?? m.scale ?? 1)
        ]
        setMonitor.running = true
    }

    // ── Scale factor: fit the total pixel canvas into the preview area ──────────
    readonly property real totalW: {
        var mx = 0
        if (!Hyprland.monitors) return 1920
        for (var i = 0; i < Hyprland.monitors.values.length; i++) {
            var m = Hyprland.monitors.values[i]
            if (m) mx = Math.max(mx, m.x + m.width)
        }
        return mx > 0 ? mx : 1920
    }
    readonly property real previewScale:
        root.width > 64 ? Math.min((root.width - 32) / totalW, 0.18) : 0.1

    ColumnLayout {
        anchors.fill: parent
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
                text: Hyprland.monitors.values.length + " connected"
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
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: root.selectedMonitor !== null

            Column {
                spacing: 2
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
                          "scale " + (root.selectedMonitor?.scale ?? 1) + "  ·  " +
                          "(" + (root.selectedMonitor?.x ?? 0) + ", " + (root.selectedMonitor?.y ?? 0) + ")"
                    color: Theme.gray
                    font.pixelSize: 11
                    font.family: Theme.font
                }
            }

            // ── Resolution ────────────────────────────────────────────────
            Column {
                Layout.fillWidth: true
                spacing: 4
                visible: root.resolutions.length > 0

                Text {
                    text: "Resolution"
                    color: Theme.gray
                    font.pixelSize: 11
                    font.family: Theme.font
                }
                Flow {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: root.resolutions
                        delegate: ModeChip {
                            required property var modelData
                            label: modelData.res
                            selected: root.selRes === modelData.res
                            onClicked: {
                                root.selRes = modelData.res
                                // snap to the fastest refresh available at this resolution
                                var rs = root.modes.filter(m => m.res === modelData.res)
                                                   .sort((a, b) => b.refresh - a.refresh)
                                if (rs.length > 0) {
                                    root.selRefresh = rs[0].refresh
                                    root.applyMode(modelData.res, rs[0].refresh, undefined)
                                }
                            }
                        }
                    }
                }
            }

            // ── Refresh rate ──────────────────────────────────────────────
            Column {
                Layout.fillWidth: true
                spacing: 4
                visible: root.refreshesForSel.length > 1

                Text {
                    text: "Refresh"
                    color: Theme.gray
                    font.pixelSize: 11
                    font.family: Theme.font
                }
                Flow {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: root.refreshesForSel
                        delegate: ModeChip {
                            required property var modelData
                            label: modelData.label + " Hz"
                            selected: Math.abs(root.selRefresh - modelData.refresh) < 0.5
                            onClicked: {
                                root.selRefresh = modelData.refresh
                                root.applyMode(root.selRes, modelData.refresh, undefined)
                            }
                        }
                    }
                }
            }

            // ── Scale ─────────────────────────────────────────────────────
            Column {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Scale"
                    color: Theme.gray
                    font.pixelSize: 11
                    font.family: Theme.font
                }
                Flow {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: ["1", "1.25", "1.5", "2"]
                        delegate: ModeChip {
                            required property string modelData
                            label: modelData + "×"
                            selected: (root.selectedMonitor?.scale ?? 1).toString() === modelData
                            onClicked: root.applyMode(root.selRes, root.selRefresh, modelData)
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

        Item { Layout.fillHeight: true }
    }

    // Compact selectable chip used by the resolution / refresh / scale rows.
    component ModeChip: Rectangle {
        property string label: ""
        property bool selected: false
        signal clicked()

        implicitWidth: chipLabel.implicitWidth + 16
        height: 26
        radius: 6
        color: selected ? Theme.accentBg : (chipArea.containsMouse ? Theme.border : Theme.bgAlt)
        Behavior on color { ColorAnimation { duration: 80 } }

        Text {
            id: chipLabel
            anchors.centerIn: parent
            text: parent.label
            color: parent.selected ? Theme.accent : Theme.fg
            font.pixelSize: 11
            font.family: Theme.font
        }
        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
