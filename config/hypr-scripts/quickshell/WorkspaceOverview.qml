// WorkspaceOverview.qml — Fullscreen workspace exposé ("mission control").
// A grid of workspace tiles, each drawing its windows as geometry-accurate
// rectangles (scaled from the real hyprctl layout). Click a window to focus it,
// click a tile's empty area to switch to that workspace. Esc / click-off closes.
//
// State comes from `hyprctl clients/monitors/workspaces -j` parsed once per open
// (and lightly re-polled), matching the Process+JSON pattern used elsewhere —
// rather than live screencopy thumbnails, which Quickshell 0.3.0 can't map to
// individual toplevels reliably.
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    signal closeRequested()

    anchors { top: true; left: true; right: true; bottom: true }
    exclusiveZone: -1
    color: "transparent"

    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // [{ id, name, focused, active, windows: [{address, cls, title, rx, ry, rw, rh}] }]
    property var workspaces: []
    // Clients stashed on special workspaces: [{address, cls, title}]
    property var scratchpad: []

    onVisibleChanged: {
        if (visible) { refresh(); pollTimer.start() }
        else         { pollTimer.stop() }
    }

    function refresh() { queryProc.running = true }
    Timer { id: pollTimer; interval: 1500; repeat: true; onTriggered: root.refresh() }

    Process { id: actProc; command: [] }
    function run(args) {
        actProc.command = args
        actProc.running = true
        root.closeRequested()
    }

    // Pull all three views in one shot; jq assembles them into one object so we
    // parse a single JSON blob. Each hyprctl call defaults to [] if it fails.
    Process {
        id: queryProc
        command: ["bash", "-c",
            "jq -n " +
            "--argjson c \"$(hyprctl clients -j 2>/dev/null || echo '[]')\" " +
            "--argjson m \"$(hyprctl monitors -j 2>/dev/null || echo '[]')\" " +
            "--argjson w \"$(hyprctl workspaces -j 2>/dev/null || echo '[]')\" " +
            "'{clients:$c,monitors:$m,workspaces:$w}'"]
        stdout: StdioCollector {
            onStreamFinished: root.rebuild(text)
        }
    }

    // Build the workspace→windows model with per-window fractional geometry.
    function rebuild(text) {
        var data
        try { data = JSON.parse(text) } catch (e) { return }
        if (!data) return

        // Monitor logical geometry by name, and the focused monitor's workspace.
        var monByName = ({})
        var focusedWsId = -1
        for (var i = 0; i < data.monitors.length; i++) {
            var m = data.monitors[i]
            var scale = m.scale || 1
            monByName[m.name] = {
                x: m.x, y: m.y,
                w: m.width / scale, h: m.height / scale
            }
            if (m.focused) focusedWsId = m.activeWorkspace ? m.activeWorkspace.id : -1
        }

        // Workspaces that are currently shown on some monitor (for the badge).
        var activeIds = ({})
        for (var a = 0; a < data.monitors.length; a++)
            if (data.monitors[a].activeWorkspace)
                activeIds[data.monitors[a].activeWorkspace.id] = true

        // Seed tiles from the workspace list (skip special/scratchpad: id < 1).
        var wsMap = ({})
        for (var j = 0; j < data.workspaces.length; j++) {
            var w = data.workspaces[j]
            if (w.id < 1) continue
            wsMap[w.id] = {
                id: w.id, name: w.name, mon: monByName[w.monitor] || null,
                focused: w.id === focusedWsId, active: activeIds[w.id] === true,
                windows: []
            }
        }

        // Place each client into its workspace tile as a fractional rectangle;
        // special-workspace clients go to the scratchpad shelf instead.
        var pads = []
        for (var k = 0; k < data.clients.length; k++) {
            var c = data.clients[k]
            if (!c.mapped) continue
            var wid = c.workspace ? c.workspace.id : -1
            if (wid < 1) {
                if (c.workspace && String(c.workspace.name).indexOf("special") === 0)
                    pads.push({
                        address: c.address,
                        cls: c.class || c.title || "",
                        title: c.title || ""
                    })
                continue
            }
            var ws = wsMap[wid]
            if (!ws) continue
            var mon = ws.mon
            if (!mon || mon.w <= 0 || mon.h <= 0) continue

            var rx = (c.at[0] - mon.x) / mon.w
            var ry = (c.at[1] - mon.y) / mon.h
            var rw = c.size[0] / mon.w
            var rh = c.size[1] / mon.h
            // Clamp into the tile; keep a sliver visible for off-screen windows.
            rx = Math.max(0, Math.min(0.98, rx))
            ry = Math.max(0, Math.min(0.98, ry))
            rw = Math.max(0.02, Math.min(1 - rx, rw))
            rh = Math.max(0.02, Math.min(1 - ry, rh))

            ws.windows.push({
                address: c.address,
                cls: c.class || c.title || "",
                title: c.title || "",
                rx: rx, ry: ry, rw: rw, rh: rh
            })
        }

        var out = []
        for (var id in wsMap) out.push(wsMap[id])
        out.sort((p, q) => p.id - q.id)
        root.workspaces = out

        pads.sort((p, q) => p.cls.localeCompare(q.cls))
        root.scratchpad = pads
    }

    // ── Esc to close ──────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closeRequested()
    }

    // ── Dimmer (click-off closes) ───────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.7)
        MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(root.width - 96, grid.implicitWidth)
        spacing: 18

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Overview"
            color: Theme.fgBright
            font.pixelSize: 18
            font.bold: true
            font.family: Theme.font
        }

        Grid {
            id: grid
            Layout.alignment: Qt.AlignHCenter
            columns: Math.max(1, Math.min(4, root.workspaces.length))
            spacing: 18

            readonly property int tileW: 360
            readonly property int tileH: 203   // ~16:9

            Repeater {
                model: root.workspaces

                delegate: Rectangle {
                    id: tile
                    required property var modelData

                    width: grid.tileW
                    height: grid.tileH + 26
                    radius: 12
                    color: "transparent"

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 4

                        // Workspace canvas
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: grid.tileH
                            radius: 10
                            color: Theme.bgHard
                            border.width: tile.modelData.focused ? 2 : 1
                            border.color: tile.modelData.focused ? Theme.accent
                                        : tileArea.containsMouse ? Theme.borderStrong : Theme.border
                            clip: true

                            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                            // Big faint workspace number behind the windows
                            Text {
                                anchors.centerIn: parent
                                text: tile.modelData.name
                                color: Theme.border
                                font.pixelSize: 64
                                font.bold: true
                                font.family: Theme.font
                                visible: tile.modelData.windows.length === 0
                            }

                            // Click empty canvas → switch to this workspace.
                            // Dispatch strings are Lua — classic "workspace N"
                            // syntax is rejected and fails silently.
                            MouseArea {
                                id: tileArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.run(["hyprctl", "dispatch",
                                    "hl.dsp.focus({ workspace = " + tile.modelData.id + " })"])
                            }

                            // Windows, drawn at their real relative geometry
                            Repeater {
                                model: tile.modelData.windows

                                delegate: Rectangle {
                                    id: win
                                    required property var modelData

                                    x: modelData.rx * parent.width
                                    y: modelData.ry * parent.height
                                    width:  Math.max(18, modelData.rw * parent.width)
                                    height: Math.max(14, modelData.rh * parent.height)
                                    radius: 5
                                    color: winArea.containsMouse ? Theme.accentBg : Theme.bgAlt
                                    border.width: 1
                                    border.color: winArea.containsMouse ? Theme.accent : Theme.borderStrong

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    Text {
                                        anchors {
                                            fill: parent
                                            leftMargin: 6; rightMargin: 6
                                            topMargin: 4; bottomMargin: 4
                                        }
                                        text: win.modelData.cls
                                        color: winArea.containsMouse ? Theme.accent : Theme.fgDim
                                        font.pixelSize: 11
                                        font.family: Theme.font
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    MouseArea {
                                        id: winArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.run(["hyprctl", "dispatch",
                                            "hl.dsp.focus({ window = hl.get_window('address:"
                                            + win.modelData.address + "') })"])
                                    }
                                }
                            }
                        }

                        // Tile footer: workspace id + window count
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4
                            spacing: 6

                            Text {
                                text: "Workspace " + tile.modelData.name
                                color: tile.modelData.focused ? Theme.accent : Theme.gray
                                font.pixelSize: 11
                                font.bold: tile.modelData.focused
                                font.family: Theme.font
                                Layout.fillWidth: true
                            }
                            Text {
                                visible: tile.modelData.windows.length > 0
                                text: tile.modelData.windows.length
                                    + (tile.modelData.windows.length === 1 ? " window" : " windows")
                                color: Theme.grayDim
                                font.pixelSize: 10
                                font.family: Theme.font
                            }
                        }
                    }
                }
            }
        }

        // ── Scratchpad shelf: chips for special-workspace windows ─────────────
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            visible: root.scratchpad.length > 0
            radius: 10
            color: Theme.bgHard
            border.width: 1
            border.color: Theme.border
            implicitWidth: shelfRow.implicitWidth + 28
            implicitHeight: shelfRow.implicitHeight + 18

            RowLayout {
                id: shelfRow
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: "Scratchpad"
                    color: Theme.orange
                    font.pixelSize: 11
                    font.bold: true
                    font.family: Theme.font
                }

                Repeater {
                    model: root.scratchpad

                    delegate: Rectangle {
                        id: chip
                        required property var modelData

                        radius: 5
                        color: chipArea.containsMouse ? Theme.accentBg : Theme.bgAlt
                        border.width: 1
                        border.color: chipArea.containsMouse ? Theme.orange : Theme.borderStrong
                        implicitWidth: chipText.implicitWidth + 18
                        implicitHeight: 24

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.modelData.cls
                            color: chipArea.containsMouse ? Theme.orange : Theme.fgDim
                            font.pixelSize: 11
                            font.family: Theme.font
                        }

                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.run(["hyprctl", "dispatch",
                                "hl.dsp.focus({ window = hl.get_window('address:"
                                + chip.modelData.address + "') })"])
                        }
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Esc or click outside to close"
            color: Theme.gray
            font.pixelSize: 11
            font.family: Theme.font
        }
    }
}
