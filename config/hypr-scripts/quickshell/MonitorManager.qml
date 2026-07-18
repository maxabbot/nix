// MonitorManager.qml — Display layout page (embedded in Settings.qml — no window chrome).
// Shows a scaled visual representation of connected monitors using Hyprland.monitors.
// Clicking a monitor selects it; the detail pane changes resolution, refresh,
// scale, orientation, position and mirroring. Monitors can also be dragged
// around the map, snapping to their neighbours' edges.
//
// Everything applies through `hyprctl eval` (see applyMonitor — the Lua parser
// this config uses rejects `hyprctl keyword`), which is session-only. "Save
// layout" hands the live state to monitor-layout.sh, which persists it to
// ~/.config/hypr/monitors-local.lua for monitors.lua to load on the next start.
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // Selection is held by connector name, not by object reference: a
    // refreshMonitors() swaps the model's entries, and a reference would go
    // stale (or dangle) the moment the layout changes under us.
    property string selectedName: ""
    readonly property var selectedMonitor: root.monitorByName(root.selectedName)

    // Mode list for the selected monitor, parsed from hyprctl availableModes.
    property var    modes:      []   // [{res, w, h, refresh, label}]
    property string selRes:     ""   // "2560x1440"
    property real   selRefresh: 0

    // Target output for the relative-placement chips ("Left of" etc.).
    property string relTarget: ""

    // Layout persistence (monitor-layout.sh save/reset).
    property bool   hasSavedLayout: false
    property string layoutStatus:   ""

    // External-monitor brightness over DDC/CI (ddcutil). Empty for displays
    // without DDC support (laptop eDP, some GPUs) — the section hides itself.
    property var ddcDisplays: []     // [{bus, model, max, brightness}]

    Process { id: setMonitor; command: [] }

    // Hyprland emits no IPC event when a monitor is reconfigured through
    // `hyprctl eval` — verified by watching .socket2.sock across two live
    // changes, which produced nothing. So Quickshell's monitor model would
    // stay stale forever, leaving every chip unhighlighted and, worse,
    // feeding applyMonitor a stale transform that silently un-rotates the
    // screen on the next scale change. Nothing pushes, so we pull.
    Timer {
        id: refreshAfterApply
        interval: 250   // Hyprland applies asynchronously; let it land first
        onTriggered: Hyprland.refreshMonitors()
    }

    onVisibleChanged: if (visible) {
        pollDdc.running = true
        checkSaved.running = true
        Hyprland.refreshMonitors()   // the layout may have changed while closed
    }

    // ── Layout persistence ──────────────────────────────────────────────────
    Process {
        id: checkSaved
        command: ["bash", "-c",
            "test -f \"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/monitors-local.lua\" && echo yes || echo no"]
        stdout: SplitParser { onRead: (line) => root.hasSavedLayout = (line.trim() === "yes") }
    }

    // Both actions re-check afterwards so the Reset button and the "saved"
    // hint reflect what's actually on disk rather than what we assumed.
    Process {
        id: layoutAction
        command: []
        property string verb: ""
        onRunningChanged: {
            if (running) return
            root.layoutStatus = exitCode === 0
                ? (verb === "save" ? "Layout saved" : "Reverted to the Nix layout")
                : "Failed to " + verb + " layout"
            statusFade.restart()
            checkSaved.running = true
        }
    }
    Timer { id: statusFade; interval: 4000; onTriggered: root.layoutStatus = "" }

    function runLayout(verb) {
        layoutAction.verb = verb
        layoutAction.command = ["bash", "-c",
            "exec \"$HOME/.config/hypr/scripts/monitor-layout.sh\" \"$1\"", "bash", verb]
        layoutAction.running = true
    }

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

    // Keyed on the name, not the object: refreshMonitors() replaces model
    // entries constantly, and re-running this on every refresh would re-fetch
    // the mode list and stomp the user's in-progress chip choices.
    onSelectedNameChanged: {
        var selectedMonitor = root.selectedMonitor
        if (selectedMonitor) {
            selRes = selectedMonitor.width + "x" + selectedMonitor.height
            selRefresh = selectedMonitor.refreshRate
            modes = []
            // Keep the relative-placement target valid: it can never be the
            // monitor we just selected, and the one we had may since have been
            // unplugged.
            var others = root.otherMonitors
            root.relTarget = others.some(o => o.name === root.relTarget)
                ? root.relTarget
                : (others.length > 0 ? others[0].name : "")
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

    function transformOf(m) { return m?.lastIpcObject?.transform ?? 0 }

    function monitorByName(n) {
        var vals = Hyprland.monitors?.values ?? []
        for (var i = 0; i < vals.length; i++)
            if (vals[i]?.name === n) return vals[i]
        return null
    }

    // Orientation of the selection, unpacked for the chip rows.
    readonly property int  selTransform: root.transformOf(root.selectedMonitor)
    readonly property int  selRotation:  selTransform % 4
    readonly property bool selFlipped:   selTransform >= 4

    // Every connected monitor except the selected one — the "relative to"
    // candidates for the placement chips.
    readonly property var otherMonitors: {
        var out = [], vals = Hyprland.monitors?.values ?? []
        for (var i = 0; i < vals.length; i++)
            if (vals[i] && vals[i].name !== root.selectedMonitor?.name) out.push(vals[i])
        return out
    }

    // Apply a monitor spec.
    //
    // This config drives Hyprland through its Lua parser (configType = "lua" in
    // modules/home/wm/hyprland.nix), and Hyprland refuses `hyprctl keyword`
    // there outright — "keyword can't work with non-legacy parsers. Use eval."
    // So changes go through `hyprctl eval`, calling the very same hl.monitor()
    // that the Nix-generated monitors.lua uses.
    //
    // The call is total: every field is re-sent each time, so anything absent
    // from `o` is read back off the monitor's live state. Dropping transform
    // would un-rotate a rotated screen; dropping position would re-place it.
    //
    // o: { res, refresh, scale, x, y, transform }
    function applyMonitor(m, o) {
        if (!m) return
        o = o ?? ({})

        // selRes/selRefresh track the chips in the detail pane, so they only
        // speak for the selected monitor — a dragged one uses its own mode.
        var isSel   = root.selectedMonitor?.name === m.name
        var res     = o.res     ?? ((isSel && root.selRes)     ? root.selRes     : m.width + "x" + m.height)
        var refresh = o.refresh ?? ((isSel && root.selRefresh) ? root.selRefresh : m.refreshRate)
        var scale   = o.scale     ?? (m.scale ?? 1)
        var t       = o.transform ?? root.transformOf(m)

        setMonitor.command = ["hyprctl", "eval",
            "hl.monitor({ output = \"" + m.name + "\"" +
            ", mode = \"" + res + "@" + Math.round(refresh) + "\"" +
            ", position = \"" + (o.x ?? m.x) + "x" + (o.y ?? m.y) + "\"" +
            ", scale = " + scale +
            ", transform = " + t + " })"]
        setMonitor.running = true

        // Pull the new state back, or the chips keep showing the old one.
        refreshAfterApply.restart()
    }

    // ── Positioning ─────────────────────────────────────────────────────────
    // Place the selected monitor flush against `relTarget` on the given side,
    // aligning their top (or left) edges. Logical sizes, so this stays correct
    // for scaled and rotated outputs.
    function placeRelative(dir) {
        var m = root.selectedMonitor
        var t = root.monitorByName(root.relTarget)
        if (!m || !t || t.name === m.name) return

        var ms = root.logicalSize(m), ts = root.logicalSize(t)
        var x = m.x, y = m.y
        if (dir === "left")  { x = t.x - ms.w;  y = t.y }
        if (dir === "right") { x = t.x + ts.w;  y = t.y }
        if (dir === "above") { y = t.y - ms.h;  x = t.x }
        if (dir === "below") { y = t.y + ts.h;  x = t.x }

        root.applyMonitor(m, { x: Math.round(x), y: Math.round(y) })
    }

    // Pull a dragged position onto a neighbour's edge when it lands close
    // enough — butting monitors up flush by hand is otherwise fiddly. Distance
    // is in logical pixels so the feel doesn't change with previewScale.
    readonly property int snapThreshold: 140

    function snapPosition(m, lx, ly) {
        var ms = root.logicalSize(m)
        var bestX = lx, bestY = ly
        var dx = root.snapThreshold, dy = root.snapThreshold
        var vals = Hyprland.monitors?.values ?? []

        for (var i = 0; i < vals.length; i++) {
            var o = vals[i]
            if (!o || o.name === m.name) continue
            var os = root.logicalSize(o)

            // Butt against either side, or align the matching edges.
            var xs = [o.x + os.w, o.x - ms.w, o.x, o.x + os.w - ms.w]
            for (var j = 0; j < xs.length; j++) {
                var d = Math.abs(lx - xs[j])
                if (d < dx) { dx = d; bestX = xs[j] }
            }
            var ys = [o.y + os.h, o.y - ms.h, o.y, o.y + os.h - ms.h]
            for (var k = 0; k < ys.length; k++) {
                var e = Math.abs(ly - ys[k])
                if (e < dy) { dy = e; bestY = ys[k] }
            }
        }
        return { x: Math.round(bestX), y: Math.round(bestY) }
    }

    // Turn a dropped tile's pixel position back into logical coordinates.
    function commitDrag(m, px, py) {
        var lx = px / root.previewScale + root.bbox.x
        var ly = py / root.previewScale + root.bbox.y
        var p = root.snapPosition(m, lx, ly)
        root.applyMonitor(m, { x: p.x, y: p.y })
    }

    // ── Preview geometry ────────────────────────────────────────────────────
    // Hyprland positions monitors in logical (post-scale) coordinates, but the
    // IPC width/height are physical mode pixels, unswapped for rotation.
    // logicalSize converts one monitor; bbox is the union of all logical rects.
    function logicalSize(m) {
        var s = m.scale || 1
        var w = m.width / s, h = m.height / s
        return (root.transformOf(m) % 2) ? ({ w: h, h: w }) : ({ w: w, h: h })
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
                text: Hyprland.monitors.values.length + " connected  ·  drag to arrange"
                color: Theme.gray
                font.pixelSize: 11
                font.family: Theme.font
            }
        }

        // ── Visual map ─────────────────────────────────────────────────────
        Rectangle {
            id: mapArea
            Layout.fillWidth: true
            // Roomy enough to drag a monitor clear of its neighbours without
            // immediately hitting the clip edge.
            height: 190
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
                        id: tile
                        required property var modelData

                        readonly property var lsz: root.logicalSize(modelData)
                        readonly property bool isSelected:
                            root.selectedMonitor?.name === modelData.name

                        // While dragging, x/y follow the pointer instead of the
                        // IPC position — the binding takes over again on drop,
                        // once Hyprland reports the committed coordinates.
                        property bool dragging: false
                        property real dragX: 0
                        property real dragY: 0

                        x: dragging ? dragX : (modelData.x - root.bbox.x) * root.previewScale
                        y: dragging ? dragY : (modelData.y - root.bbox.y) * root.previewScale
                        width:  lsz.w * root.previewScale
                        height: lsz.h * root.previewScale

                        z: dragging ? 1 : 0
                        opacity: dragging ? 0.85 : 1

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

                        // Click selects; drag repositions. Hyprland's own
                        // coordinates are the source of truth, so the drag only
                        // moves the tile locally and commits on release.
                        MouseArea {
                            id: tileArea
                            anchors.fill: parent
                            cursorShape: tile.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                            // Grab point in item coordinates. Because x/y move
                            // with the drag, (mouse - grab) stays the delta.
                            property real grabX: 0
                            property real grabY: 0

                            onPressed: (mouse) => {
                                root.selectedName = tile.modelData.name
                                grabX = mouse.x
                                grabY = mouse.y
                                tile.dragX = tile.x
                                tile.dragY = tile.y
                            }
                            onPositionChanged: (mouse) => {
                                if (!pressed) return
                                // Small movements are a click with a shaky hand,
                                // not a drag — don't nudge the layout for them.
                                if (!tile.dragging) {
                                    if (Math.abs(mouse.x - grabX) + Math.abs(mouse.y - grabY) < 4) return
                                    tile.dragging = true
                                }
                                tile.dragX += mouse.x - grabX
                                tile.dragY += mouse.y - grabY
                            }
                            onReleased: {
                                if (!tile.dragging) return   // plain click: selection only
                                tile.dragging = false
                                root.commitDrag(tile.modelData, tile.dragX, tile.dragY)
                            }
                            onCanceled: tile.dragging = false
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
                                    root.applyMonitor(root.selectedMonitor,
                                                      { res: modelData.res, refresh: rs[0].refresh })
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
                                root.applyMonitor(root.selectedMonitor, { refresh: modelData.refresh })
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
                            // Float compare — Hyprland reports scale as a double
                            // (1.00, 1.25), so string equality is too brittle.
                            selected: Math.abs((root.selectedMonitor?.scale ?? 1)
                                               - parseFloat(modelData)) < 0.01
                            onClicked: root.applyMonitor(root.selectedMonitor,
                                                         { scale: parseFloat(modelData) })
                        }
                    }
                }
            }

            // ── Orientation ───────────────────────────────────────────────
            // Hyprland packs rotation and flip into one transform value:
            // 0-3 are 0/90/180/270°, 4-7 the same rotations flipped.
            Column {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Orientation"
                    color: Theme.gray
                    font.pixelSize: 11
                    font.family: Theme.font
                }
                Flow {
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: [
                            { rot: 0, label: "0°"   },
                            { rot: 1, label: "90°"  },
                            { rot: 2, label: "180°" },
                            { rot: 3, label: "270°" },
                        ]
                        delegate: ModeChip {
                            required property var modelData
                            label: modelData.label
                            selected: root.selRotation === modelData.rot
                            onClicked: root.applyMonitor(root.selectedMonitor, {
                                transform: modelData.rot + (root.selFlipped ? 4 : 0)
                            })
                        }
                    }

                    // Spacer, so Flip reads as a separate control from rotation.
                    Item { width: 8; height: 1 }

                    ModeChip {
                        label: "Flip"
                        selected: root.selFlipped
                        onClicked: root.applyMonitor(root.selectedMonitor, {
                            transform: root.selRotation + (root.selFlipped ? 0 : 4)
                        })
                    }
                }
            }

            // ── Position ──────────────────────────────────────────────────
            Column {
                Layout.fillWidth: true
                spacing: 4
                visible: root.otherMonitors.length > 0

                Text {
                    text: "Position"
                    color: Theme.gray
                    font.pixelSize: 11
                    font.family: Theme.font
                }
                Flow {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: [
                            { dir: "left",  label: "Left of"  },
                            { dir: "right", label: "Right of" },
                            { dir: "above", label: "Above"    },
                            { dir: "below", label: "Below"    },
                        ]
                        delegate: ModeChip {
                            required property var modelData
                            label: modelData.label
                            onClicked: root.placeRelative(modelData.dir)
                        }
                    }
                }

                Item { width: 1; height: 2 }

                Text {
                    text: "relative to"
                    color: Theme.grayDim
                    font.pixelSize: 10
                    font.family: Theme.font
                }
                Flow {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: root.otherMonitors
                        delegate: ModeChip {
                            required property var modelData
                            label: modelData.name
                            selected: root.relTarget === modelData.name
                            onClicked: root.relTarget = modelData.name
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

        // ── Persistence ───────────────────────────────────────────────────
        // Everything above is a live `hyprctl eval`, i.e. gone on replug/reload.
        // Save writes the live layout to ~/.config/hypr/monitors-local.lua,
        // which monitors.lua loads last; Reset deletes it and reloads.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: root.layoutStatus !== "" ? root.layoutStatus
                        : root.hasSavedLayout ? "Saved layout active — overrides the Nix defaults"
                        : "Changes apply to this session only"
                    color: root.layoutStatus !== "" ? Theme.green : Theme.grayDim
                    font.pixelSize: 10
                    font.family: Theme.font
                    elide: Text.ElideRight
                }

                ModeChip {
                    label: "Save layout"
                    onClicked: root.runLayout("save")
                }
                ModeChip {
                    label: "Reset"
                    enabled: root.hasSavedLayout
                    opacity: root.hasSavedLayout ? 1 : 0.4
                    onClicked: root.runLayout("reset")
                }
            }
        }
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
