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

    // External-monitor brightness over DDC/CI (ddcutil). Empty for displays
    // without DDC support (laptop eDP, some GPUs) — the section hides itself.
    property var ddcDisplays: []     // [{bus, model, max, brightness}]

    Process { id: setMonitor; command: [] }

    onVisibleChanged: if (visible) pollDdc.running = true

    // Enumerate DDC displays and read each one's brightness (VCP feature 0x10)
    // in a single pass. Slow (~1-2s) so it only runs when the tab opens.
    Process {
        id: pollDdc
        command: ["bash", "-c",
            "command -v ddcutil >/dev/null 2>&1 || exit 0; " +
            "ddcutil detect --brief 2>/dev/null | awk '" +
            "  /^Display/{b=\"\";m=\"\"} " +
            "  /I2C bus/{n=$0; sub(/.*i2c-/,\"\",n); sub(/[^0-9].*/,\"\",n); b=n} " +
            "  /Monitor:/{m=$0; sub(/.*Monitor:[ \\t]*/,\"\",m)} " +
            "  b!=\"\"&&m!=\"\"{print b\"|\"m; b=\"\";m=\"\"}' | " +
            "while IFS='|' read -r bus model; do " +
            "  vcp=$(ddcutil --bus \"$bus\" getvcp 10 --brief 2>/dev/null); " +
            "  cur=$(printf '%s' \"$vcp\" | awk '{print $4}'); " +
            "  max=$(printf '%s' \"$vcp\" | awk '{print $5}'); " +
            "  [ -z \"$cur\" ] && continue; " +
            "  name=$(printf '%s' \"$model\" | awk -F: '{print ($2!=\"\"?$2:$1)}'); " +
            "  echo \"$bus|$name|$cur|${max:-100}\"; " +
            "done"]
        property var accum: []
        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim() === "") return
                var p = line.split("|")
                if (p.length < 4) return
                var max = parseInt(p[3]) || 100
                var cur = parseInt(p[2]) || 0
                pollDdc.accum.push({
                    bus: parseInt(p[0]), model: (p[1] || ("Bus " + p[0])).trim(),
                    max: max, brightness: cur / max
                })
            }
        }
        onRunningChanged: { if (running) accum = []; else { root.ddcDisplays = accum; accum = [] } }
    }

    // Debounced brightness write — dragging a slider fires continuously, but a
    // ddcutil setvcp takes ~200ms, so coalesce to the last value.
    property int _ddcBus: -1
    property int _ddcVal: 0
    Process { id: setDdc; command: [] }
    Timer {
        id: ddcDebounce
        interval: 200
        onTriggered: {
            if (root._ddcBus < 0) return
            setDdc.command = ["ddcutil", "--bus", String(root._ddcBus), "setvcp", "10", String(root._ddcVal)]
            setDdc.running = true
        }
    }
    function setDdcBrightness(bus, frac, max) {
        root._ddcBus = bus
        root._ddcVal = Math.round(Math.max(0, Math.min(1, frac)) * max)
        ddcDebounce.restart()
    }

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

    // Apply res@refresh (+ scale) to the selected monitor, keeping its
    // position and transform (omitting transform would un-rotate it).
    function applyMode(res, refresh, scale) {
        if (!root.selectedMonitor) return
        var m = root.selectedMonitor
        var t = m.lastIpcObject?.transform ?? 0
        setMonitor.command = [
            "hyprctl", "keyword", "monitor",
            m.name + "," + res + "@" + refresh + "," +
            m.x + "x" + m.y + "," + (scale ?? m.scale ?? 1) +
            (t ? ",transform," + t : "")
        ]
        setMonitor.running = true
    }

    // ── Preview geometry ────────────────────────────────────────────────────
    // Hyprland positions monitors in logical (post-scale) coordinates, but the
    // IPC width/height are physical mode pixels, unswapped for rotation.
    // logicalSize converts one monitor; bbox is the union of all logical rects.
    function logicalSize(m) {
        var s = m.scale || 1
        var w = m.width / s, h = m.height / s
        return ((m.lastIpcObject?.transform ?? 0) % 2) ? ({ w: h, h: w }) : ({ w: w, h: h })
    }
    readonly property var bbox: {
        var vals = Hyprland.monitors?.values ?? []
        var x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity
        for (var i = 0; i < vals.length; i++) {
            var m = vals[i]
            if (!m) continue
            var sz = logicalSize(m)
            x0 = Math.min(x0, m.x);        y0 = Math.min(y0, m.y)
            x1 = Math.max(x1, m.x + sz.w); y1 = Math.max(y1, m.y + sz.h)
        }
        return x0 < x1 ? { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }
                       : { x: 0, y: 0, w: 1920, h: 1080 }
    }
    readonly property real previewScale:
        root.width > 64
            ? Math.min((root.width - 32) / bbox.w, (mapArea.height - 24) / bbox.h, 0.18)
            : 0.1

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
            id: mapArea
            Layout.fillWidth: true
            height: 160
            radius: 8
            color: Theme.bgHard
            clip: true

            Item {
                // Centre the monitor map in the preview area
                anchors.centerIn: parent
                width: root.bbox.w * root.previewScale
                height: root.bbox.h * root.previewScale

                Repeater {
                    model: Hyprland.monitors

                    delegate: Rectangle {
                        required property var modelData

                        readonly property var lsz: root.logicalSize(modelData)
                        readonly property bool isSelected:
                            root.selectedMonitor?.name === modelData.name

                        x: (modelData.x - root.bbox.x) * root.previewScale
                        y: (modelData.y - root.bbox.y) * root.previewScale
                        width:  lsz.w * root.previewScale
                        height: lsz.h * root.previewScale

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

        // ── External brightness (DDC/CI) ──────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: root.ddcDisplays.length > 0

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

            Text {
                text: "Brightness"
                color: Theme.gray
                font.pixelSize: 11
                font.bold: true
                font.family: Theme.font
            }

            Repeater {
                model: root.ddcDisplays

                delegate: SliderRow {
                    required property var modelData
                    Layout.fillWidth: true
                    label: modelData.model
                    value: modelData.brightness   // initial; drag overrides
                    onMoved: (v) => {
                        value = v
                        root.setDdcBrightness(modelData.bus, v, modelData.max)
                    }
                }
            }
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
