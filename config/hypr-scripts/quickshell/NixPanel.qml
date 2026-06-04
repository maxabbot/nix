// NixPanel.qml — Combined Nix store gauge + live rebuild tracker (bottom-right).
// Store gauge shows /nix partition usage via `df`.
// Rebuild runs `nh os switch /etc/nixos` or `nh home switch` and streams output.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

PanelWindow {
    id: root

    anchors { bottom: true; right: true }
    margins { bottom: 44; right: 4 }
    implicitWidth: 480
    implicitHeight: 660
    color: "transparent"

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
        command: ["bash", "-c", "ls /nix/store | wc -l"]
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
        logModel.append({ text: clean, color: color || "#bdae93" })
        // Keep last 300 lines
        if (logModel.count > 300) logModel.remove(0)
        Qt.callLater(() => { logView.positionViewAtEnd() })
    }

    function logColor(line) {
        var l = line.toLowerCase()
        if (/error:|failed|abort/i.test(l))                     return "#ea6962"
        if (/warning:|warn:/i.test(l))                          return "#d8a657"
        if (/building '|copying '|fetching '|downloading/i.test(l)) return "#7daea3"
        if (/✓|activated|done\b|success|finished/i.test(l))    return "#a9b665"
        return "#bdae93"
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
                           ok ? "#a9b665" : "#ea6962")
            root.rebuildFinished(ok)
            pollDisk.running = true
            pollPaths.running = true
        }
    }

    Process { id: gcProcess; command: [] }

    // ── UI ───────────────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 12; color: "#282828"
        border.color: "#3c3836"; border.width: 1

        ColumnLayout {
            anchors { fill: parent; margins: 12 }
            spacing: 10

            // ── Header ──────────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true; height: 28; spacing: 8
                Text {
                    text: "󱄅  Nix"
                    color: "#d4be98"; font.pixelSize: 14; font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                    Layout.fillWidth: true
                }
                Rectangle {
                    visible: root.rebuildStatus !== "idle"
                    radius: 4; color: "#1d2021"
                    border.color: root.rebuildStatus === "success" ? "#a9b665"
                                : root.rebuildStatus === "failed"  ? "#ea6962" : "#7daea3"
                    border.width: 1
                    implicitWidth: statusLabel.implicitWidth + 10
                    implicitHeight: statusLabel.implicitHeight + 4
                    Text {
                        id: statusLabel
                        anchors.centerIn: parent
                        text: root.rebuildStatus
                        color: root.rebuildStatus === "success" ? "#a9b665"
                             : root.rebuildStatus === "failed"  ? "#ea6962" : "#7daea3"
                        font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
                    }
                }
            }

            // ── Store gauge ──────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; height: 180; radius: 8
                color: "#32302f"; border.color: "#3c3836"; border.width: 1

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
                            ctx.strokeStyle = "#3c3836"
                            ctx.lineWidth = 10
                            ctx.stroke()

                            // Fill
                            if (fraction > 0) {
                                var start = -Math.PI / 2
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, start, start + Math.PI * 2 * Math.min(fraction, 1))
                                ctx.strokeStyle = fraction > 0.9 ? "#ea6962"
                                               : fraction > 0.75 ? "#d8a657" : "#7daea3"
                                ctx.lineWidth = 10
                                ctx.lineCap = "round"
                                ctx.stroke()
                            }

                            // Percentage text
                            ctx.font = "bold 18px JetBrainsMono Nerd Font"
                            ctx.fillStyle = "#d4be98"
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"
                            ctx.fillText(Math.round(fraction * 100) + "%", cx, cy - 8)

                            ctx.font = "11px JetBrainsMono Nerd Font"
                            ctx.fillStyle = "#928374"
                            ctx.fillText("used", cx, cy + 10)
                        }
                    }

                    // Stats column
                    Column {
                        Layout.fillWidth: true; spacing: 10

                        Column {
                            spacing: 2
                            Text { text: "Used"; color: "#928374"; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                            Text {
                                text: (root.diskUsed / 1073741824).toFixed(1) + " GB"
                                color: "#ebdbb2"; font.pixelSize: 16; font.bold: true
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }

                        Column {
                            spacing: 2
                            Text { text: "Total"; color: "#928374"; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                            Text {
                                text: (root.diskTotal / 1073741824).toFixed(1) + " GB"
                                color: "#d4be98"; font.pixelSize: 13
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }

                        Column {
                            spacing: 2
                            Text { text: "Store paths"; color: "#928374"; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                            Text {
                                text: root.storePaths.toLocaleString()
                                color: "#d4be98"; font.pixelSize: 13
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }

                        // GC button
                        Rectangle {
                            width: parent.width; height: 32; radius: 6
                            color: gcArea.containsMouse ? (gcProcess.running ? "#504945" : "#2d4a52") : "#32302f"
                            border.color: "#504945"; border.width: 1
                            Behavior on color { ColorAnimation { duration: 80 } }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                spacing: 6
                                Text {
                                    text: gcProcess.running ? "" : "󱃅"
                                    color: "#7daea3"; font.pixelSize: 13
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                                Text {
                                    text: gcProcess.running ? "Collecting…" : "Collect Garbage"
                                    color: "#d4be98"; font.pixelSize: 12
                                    font.family: "JetBrainsMono Nerd Font"
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
            Rectangle { Layout.fillWidth: true; height: 1; color: "#3c3836" }

            // ── Rebuild section ──────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true; spacing: 8

                Text {
                    text: "Rebuild"
                    color: "#928374"; font.pixelSize: 11; font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                    Layout.fillWidth: true
                }

                // NixOS switch
                Rectangle {
                    implicitWidth: nixLabel.implicitWidth + 20; height: 30; radius: 6
                    color: nixBtn.containsMouse && !root.rebuilding ? "#2d4a52" : "#32302f"
                    border.color: "#504945"; border.width: 1
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text {
                        id: nixLabel
                        anchors.centerIn: parent
                        text: "NixOS Switch"
                        color: root.rebuilding ? "#665c54" : "#d4be98"
                        font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
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
                    color: hmBtn.containsMouse && !root.rebuilding ? "#2d4a52" : "#32302f"
                    border.color: "#504945"; border.width: 1
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text {
                        id: hmLabel
                        anchors.centerIn: parent
                        text: "HM Switch"
                        color: root.rebuilding ? "#665c54" : "#d4be98"
                        font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
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
                color: "#1d2021"; border.color: "#3c3836"; border.width: 1

                // Empty state
                Column {
                    visible: logModel.count === 0
                    anchors.centerIn: parent; spacing: 8
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󱄅"; color: "#504945"; font.pixelSize: 28
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No rebuild log yet"
                        color: "#665c54"; font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
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
                        font.family: "JetBrainsMono Nerd Font"
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
