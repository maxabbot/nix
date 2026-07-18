// KDEConnectPanel.qml — KDE Connect page (embedded in Settings.qml — no chrome).
// Lists devices via kdeconnect-cli, pair/unpair, ring ("find my phone"), and
// ping. Needs programs.kdeconnect.enable (daemon + firewall) — see productivity.nix.
// The cli DBus-activates kdeconnectd, so the first poll also starts it.
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

Item {
    id: root

    property var    devices: []   // [{id, name, paired, reachable}]
    property bool   cliMissing: false
    property string busyId: ""

    onVisibleChanged: {
        if (visible) { refresh(); refreshTimer.start() }
        else         refreshTimer.stop()
    }

    function refresh() { listProc.running = true }
    Timer { id: refreshTimer; interval: 4000; repeat: true; onTriggered: root.refresh() }

    // Human `--list-devices` output annotates status in parens, e.g.
    //   "- Pixel: <id> (paired and reachable)". sed reshapes it to id|name|status.
    Process {
        id: listProc
        command: ["bash", "-c",
            "command -v kdeconnect-cli >/dev/null 2>&1 || { echo NOCLI; exit 0; }; " +
            "kdeconnect-cli --list-devices 2>/dev/null | " +
            "sed -n 's/^- \\(.*\\): \\([^ ]*\\) (\\(.*\\))$/\\2|\\1|\\3/p'"]
        property var accum: []
        property bool sawCli: true
        stdout: SplitParser {
            onRead: (line) => {
                var s = line.trim()
                if (s === "") return
                if (s === "NOCLI") { listProc.sawCli = false; return }
                var p = s.split("|")
                if (p.length < 3) return
                listProc.accum.push({
                    id: p[0], name: p[1] || p[0],
                    paired: p[2].indexOf("paired") >= 0,
                    reachable: p[2].indexOf("reachable") >= 0
                })
            }
        }
        onRunningChanged: {
            if (running) { accum = []; sawCli = true }
            else {
                root.cliMissing = !sawCli
                accum.sort((a, b) => (b.reachable - a.reachable) || (b.paired - a.paired)
                                     || a.name.localeCompare(b.name))
                root.devices = accum
                accum = []
            }
        }
    }

    // ── Actions ─────────────────────────────────────────────────────────────────
    Process { id: actProc; command: [] }
    Connections {
        target: actProc
        function onRunningChanged() {
            if (!actProc.running) { root.busyId = ""; Qt.callLater(root.refresh) }
        }
    }
    function devAction(flag, id, markBusy) {
        if (markBusy) root.busyId = id
        actProc.command = ["kdeconnect-cli", flag, "-d", id]
        actProc.running = true
    }

    // ── UI ──────────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Text {
            text: "KDE Connect"
            color: Theme.fg
            font.pixelSize: 14
            font.bold: true
            font.family: Theme.font
        }

        Text {
            visible: root.cliMissing
            text: "kdeconnect-cli not found — enable programs.kdeconnect"
            color: Theme.red
            font.pixelSize: 11
            font.family: Theme.font
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        Text {
            visible: !root.cliMissing && root.devices.length === 0
            text: "No devices. Pair from the KDE Connect app on your phone (same network)."
            color: Theme.grayDim
            font.pixelSize: 11
            font.family: Theme.font
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: root.width
                spacing: 4

                Repeater {
                    model: root.devices

                    delegate: Rectangle {
                        id: devRow
                        required property var modelData
                        readonly property bool busy: root.busyId === modelData.id

                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        radius: 8
                        color: modelData.reachable ? Theme.accentBg : Theme.bgAlt
                        opacity: modelData.reachable ? 1.0 : 0.6

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                            spacing: 10

                            Text {
                                text: "󰄜"
                                color: modelData.reachable ? Theme.accent : Theme.gray
                                font.pixelSize: 18
                                font.family: Theme.font
                            }
                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.name
                                    color: Theme.fg
                                    font.pixelSize: 12
                                    font.family: Theme.font
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: (modelData.paired ? "Paired" : "Not paired")
                                        + (modelData.reachable ? "  ·  reachable" : "  ·  offline")
                                    color: Theme.grayDim
                                    font.pixelSize: 9
                                    font.family: Theme.font
                                }
                            }

                            Text {
                                visible: devRow.busy
                                text: "…"
                                color: Theme.yellow
                                font.pixelSize: 14
                                font.family: Theme.font
                            }

                            // Ring / find (paired + reachable only)
                            KcButton {
                                visible: !devRow.busy && modelData.paired && modelData.reachable
                                glyph: "󰂟"
                                onActivated: root.devAction("--ring", modelData.id, false)
                            }
                            // Pair / unpair
                            KcButton {
                                visible: !devRow.busy && modelData.reachable
                                glyph: modelData.paired ? "󰗽" : "󰌷"
                                accent: !modelData.paired
                                onActivated: root.devAction(modelData.paired ? "--unpair" : "--pair", modelData.id, true)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Small round action button ───────────────────────────────────────────────
    component KcButton: Rectangle {
        id: kcb
        property string glyph: ""
        property bool accent: false
        signal activated()

        width: 30; height: 30; radius: 7
        color: kcArea.containsMouse ? Theme.borderStrong : "transparent"
        Behavior on color { ColorAnimation { duration: 80 } }

        Text {
            anchors.centerIn: parent
            text: kcb.glyph
            color: kcb.accent ? Theme.accent : Theme.gray
            font.pixelSize: 13
            font.family: Theme.font
        }
        MouseArea {
            id: kcArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: kcb.activated()
        }
    }
}
