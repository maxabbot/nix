// NixPanel.qml — Nix store gauge + live rebuild tracker page
// (embedded in Settings.qml — no window chrome).
// Store gauge shows /nix partition usage via `df`.
// Rebuild runs `nh os switch /etc/nixos` or `nh home switch` and streams output.
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

Item {
    id: root

    signal rebuildStarted()
    signal rebuildFinished(bool success)

    property bool rebuilding: false
    property string rebuildStatus: "idle"   // idle | running | success | failed

    // ── Disk stats ───────────────────────────────────────────────────────────────
    property real diskUsed:  0   // bytes
    property real diskTotal: 1   // bytes (avoid division by zero)
    property int  storePaths: 0

    onVisibleChanged: {
        if (visible) {
            pollDisk.running = true
            pollPaths.running = true
        }
    }

    Process {
        id: pollDisk
        // df -B1 gives bytes; columns: used, total
        command: ["bash", "-c", "df -B1 /nix/store --output=used,size 2>/dev/null | tail -1"]
        stdout: SplitParser {
            onRead: (line) => {
                var parts = line.trim().split(/\s+/)
                if (parts.length >= 2) {
                    root.diskUsed  = parseFloat(parts[0]) || 0
                    root.diskTotal = parseFloat(parts[1]) || 1
                }
            }
        }
    }

    Process {
        id: pollPaths
        // -U skips the sort — /nix/store can hold hundreds of thousands of entries
        command: ["bash", "-c", "ls -1U /nix/store | wc -l"]
        stdout: SplitParser {
            onRead: (line) => {
                var n = parseInt(line.trim())
                if (!isNaN(n)) root.storePaths = n
            }
        }
    }

    // ── Rebuild processes ────────────────────────────────────────────────────────
    ListModel { id: logModel }  // { text, color }

    function appendLog(text, color) {
        var clean = text.replace(/\x1b\[[0-9;?]*[a-zA-Z]/g, "").replace(/\r/g, "")
        if (!clean) return
        logModel.append({ text: clean, color: color || Theme.fgDim })
        // Keep last 300 lines
        if (logModel.count > 300) logModel.remove(0)
        Qt.callLater(() => { logView.positionViewAtEnd() })
    }

    function logColor(line) {
        var l = line.toLowerCase()
        if (/error:|failed|abort/i.test(l))                     return Theme.red
        if (/warning:|warn:/i.test(l))                          return Theme.yellow
        if (/building '|copying '|fetching '|downloading/i.test(l)) return Theme.accent
        if (/✓|activated|done\b|success|finished/i.test(l))    return Theme.green
        return Theme.fgDim
    }

    function startRebuild(cmd) {
        if (root.rebuilding) return
        logModel.clear()
        root.rebuilding = true
        root.rebuildStatus = "running"
        root.rebuildStarted()
        rebuilder.command = cmd
        rebuilder.running = true
    }

    Process {
        id: rebuilder
        command: []
        stdout: SplitParser { onRead: (line) => root.appendLog(line, root.logColor(line)) }
        stderr: SplitParser { onRead: (line) => root.appendLog(line, root.logColor(line)) }
        onExited: {
            var ok = rebuilder.exitCode === 0
            root.rebuilding = false
            root.rebuildStatus = ok ? "success" : "failed"
            root.appendLog(ok ? "── Build succeeded ──" : "── Build failed (exit " + rebuilder.exitCode + ") ──",
                           ok ? Theme.green : Theme.red)
            root.rebuildFinished(ok)
            pollDisk.running = true
            pollPaths.running = true
        }
    }

    Process { id: gcProcess; command: [] }

    // ── UI ───────────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ── Header ──────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; height: 28; spacing: 8
            Text {
                text: "󱄅  Nix"
                color: Theme.fg; font.pixelSize: 14; font.bold: true
                font.family: Theme.font
                Layout.fillWidth: true
            }
            Rectangle {
                visible: root.rebuildStatus !== "idle"
                radius: 4; color: Theme.bgHard
                border.color: root.rebuildStatus === "success" ? Theme.green
                            : root.rebuildStatus === "failed"  ? Theme.red : Theme.accent
                border.width: 1
                implicitWidth: statusLabel.implicitWidth + 10
                implicitHeight: statusLabel.implicitHeight + 4
                Text {
                    id: statusLabel
                    anchors.centerIn: parent
                    text: root.rebuildStatus
                    color: root.rebuildStatus === "success" ? Theme.green
                         : root.rebuildStatus === "failed"  ? Theme.red : Theme.accent
                    font.pixelSize: 10; font.family: Theme.font
                }
            }
        }

        // ── Store gauge ──────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 180; radius: 8
            color: Theme.bgAlt; border.color: Theme.border; border.width: 1

            RowLayout {
                anchors { fill: parent; margins: 12 }
                spacing: 16

                // Radial ring
                Canvas {
                    id: ring
                    width: 140; height: 140
                    Layout.alignment: Qt.AlignVCenter

                    property real fraction: root.diskTotal > 0 ? root.diskUsed / root.diskTotal : 0
                    onFractionChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var cx = width / 2, cy = height / 2, r = 56

                        // Track
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, 0, Math.PI * 2)
                        ctx.strokeStyle = Theme.border
                        ctx.lineWidth = 10
                        ctx.stroke()

                        // Fill
                        if (fraction > 0) {
                            var start = -Math.PI / 2
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, start, start + Math.PI * 2 * Math.min(fraction, 1))
                            ctx.strokeStyle = fraction > 0.9 ? Theme.red
                                           : fraction > 0.75 ? Theme.yellow : Theme.accent
                            ctx.lineWidth = 10
                            ctx.lineCap = "round"
                            ctx.stroke()
                        }

                        // Percentage text
                        ctx.font = "bold 18px '" + Theme.font + "'"
                        ctx.fillStyle = Theme.fg
                        ctx.textAlign = "center"
                        ctx.textBaseline = "middle"
                        ctx.fillText(Math.round(fraction * 100) + "%", cx, cy - 8)

                        ctx.font = "11px '" + Theme.font + "'"
                        ctx.fillStyle = Theme.gray
                        ctx.fillText("used", cx, cy + 10)
                    }
                }

                // Stats column
                Column {
                    Layout.fillWidth: true; spacing: 10

                    Column {
                        spacing: 2
                        Text { text: "Used"; color: Theme.gray; font.pixelSize: 10; font.family: Theme.font }
                        Text {
                            text: (root.diskUsed / 1073741824).toFixed(1) + " GB"
                            color: Theme.fgBright; font.pixelSize: 16; font.bold: true
                            font.family: Theme.font
                        }
                    }

                    Column {
                        spacing: 2
                        Text { text: "Total"; color: Theme.gray; font.pixelSize: 10; font.family: Theme.font }
                        Text {
                            text: (root.diskTotal / 1073741824).toFixed(1) + " GB"
                            color: Theme.fg; font.pixelSize: 13
                            font.family: Theme.font
                        }
                    }

                    Column {
                        spacing: 2
                        Text { text: "Store paths"; color: Theme.gray; font.pixelSize: 10; font.family: Theme.font }
                        Text {
                            text: root.storePaths.toLocaleString()
                            color: Theme.fg; font.pixelSize: 13
                            font.family: Theme.font
                        }
                    }

                    // GC button
                    Rectangle {
                        width: parent.width; height: 32; radius: 6
                        color: gcArea.containsMouse ? (gcProcess.running ? Theme.borderStrong : Theme.accentBg) : Theme.bgAlt
                        border.color: Theme.borderStrong; border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 6
                            Text {
                                text: gcProcess.running ? "" : "󱃅"
                                color: Theme.accent; font.pixelSize: 13
                                font.family: Theme.font
                            }
                            Text {
                                text: gcProcess.running ? "Collecting…" : "Collect Garbage"
                                color: Theme.fg; font.pixelSize: 12
                                font.family: Theme.font
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: gcArea
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !gcProcess.running
                            onClicked: {
                                gcProcess.command = ["nix-collect-garbage"]
                                gcProcess.running = true
                            }
                        }
                    }
                }
            }

            // GC post-refresh
            Connections {
                target: gcProcess
                function onExited() { pollDisk.running = true; pollPaths.running = true }
            }
        }

        // ── Divider ──────────────────────────────────────────────────────────
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

        // ── Rebuild section ──────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 8

            Text {
                text: "Rebuild"
                color: Theme.gray; font.pixelSize: 11; font.bold: true
                font.family: Theme.font
                Layout.fillWidth: true
            }

            // NixOS switch
            Rectangle {
                implicitWidth: nixLabel.implicitWidth + 20; height: 30; radius: 6
                color: nixBtn.containsMouse && !root.rebuilding ? Theme.accentBg : Theme.bgAlt
                border.color: Theme.borderStrong; border.width: 1
                Behavior on color { ColorAnimation { duration: 80 } }
                Text {
                    id: nixLabel
                    anchors.centerIn: parent
                    text: "NixOS Switch"
                    color: root.rebuilding ? Theme.grayDim : Theme.fg
                    font.pixelSize: 11; font.family: Theme.font
                }
                MouseArea {
                    id: nixBtn
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: root.rebuilding ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !root.rebuilding
                    onClicked: root.startRebuild(["nh", "os", "switch", "/etc/nixos"])
                }
            }

            // HM switch
            Rectangle {
                implicitWidth: hmLabel.implicitWidth + 20; height: 30; radius: 6
                color: hmBtn.containsMouse && !root.rebuilding ? Theme.accentBg : Theme.bgAlt
                border.color: Theme.borderStrong; border.width: 1
                Behavior on color { ColorAnimation { duration: 80 } }
                Text {
                    id: hmLabel
                    anchors.centerIn: parent
                    text: "HM Switch"
                    color: root.rebuilding ? Theme.grayDim : Theme.fg
                    font.pixelSize: 11; font.family: Theme.font
                }
                MouseArea {
                    id: hmBtn
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: root.rebuilding ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !root.rebuilding
                    onClicked: root.startRebuild(["nh", "home", "switch"])
                }
            }
        }

        // ── Log output ───────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: 6
            color: Theme.bgHard; border.color: Theme.border; border.width: 1

            // Empty state
            Column {
                visible: logModel.count === 0
                anchors.centerIn: parent; spacing: 8
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󱄅"; color: Theme.borderStrong; font.pixelSize: 28
                    font.family: Theme.font
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No rebuild log yet"
                    color: Theme.grayDim; font.pixelSize: 12
                    font.family: Theme.font
                }
            }

            ListView {
                id: logView
                anchors { fill: parent; margins: 8 }
                clip: true
                model: logModel
                spacing: 0
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Text {
                    width: logView.width
                    text: model.text
                    color: model.color
                    font.pixelSize: 10
                    font.family: Theme.font
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }
            }
        }
    }
}
