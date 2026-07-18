// BluetoothPanel.qml — Bluetooth page (embedded in Settings.qml — no window chrome).
// Power toggle + device list via bluetoothctl: connect/disconnect, pair/trust,
// remove, and per-device battery %. A best-effort codec/profile selector switches
// the active bluez card's A2DP profile via pactl. qs_manager.sh starts a scan on
// open (PREP_TAB == bluetooth) and tears it down on close.
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

Item {
    id: root

    property bool btPowered:   false
    property var  devices:     []   // [{mac, name, connected, paired, battery}]
    property var  codecProfiles: []  // [{id, desc, active}]
    property string codecCard: ""
    property string busyMac:   ""

    // ── Polling ─────────────────────────────────────────────────────────────────
    onVisibleChanged: {
        if (visible) { refresh(); refreshTimer.start() }
        else         refreshTimer.stop()
    }

    function refresh() {
        pollPower.running = true
        listDevices.running = true
        pollCodec.running = true
    }

    Timer { id: refreshTimer; interval: 5000; repeat: true; onTriggered: root.refresh() }

    Process {
        id: pollPower
        command: ["bash", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo on || echo off"]
        stdout: SplitParser { onRead: (line) => root.btPowered = (line.trim() === "on") }
    }

    // Emit one "mac|name|connected|paired|battery" line per known device.
    Process {
        id: listDevices
        command: ["bash", "-c",
            "bluetoothctl devices | while read -r _ mac name; do " +
            "  info=$(bluetoothctl info \"$mac\"); " +
            "  c=$(echo \"$info\" | grep -q 'Connected: yes' && echo 1 || echo 0); " +
            "  p=$(echo \"$info\" | grep -q 'Paired: yes' && echo 1 || echo 0); " +
            "  b=$(echo \"$info\" | grep -oP 'Battery Percentage: .*\\(\\K[0-9]+' || true); " +
            "  echo \"$mac|$name|$c|$p|$b\"; " +
            "done"]
        property var accum: []
        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim() === "") return
                var p = line.split("|")
                if (p.length < 4) return
                listDevices.accum.push({
                    mac: p[0], name: p[1] || p[0],
                    connected: p[2] === "1", paired: p[3] === "1",
                    battery: (p[4] ?? "").trim()
                })
            }
        }
        onRunningChanged: {
            if (running) accum = []
            else {
                // connected first, then paired, then by name
                accum.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired)
                                     || a.name.localeCompare(b.name))
                root.devices = accum
                accum = []
            }
        }
    }

    // Active bluez card + its available A2DP profiles (LDAC/AptX/SBC/…).
    Process {
        id: pollCodec
        command: ["bash", "-c",
            "card=$(pactl list cards short 2>/dev/null | awk '/bluez/{print $2; exit}'); " +
            "[ -z \"$card\" ] && exit 0; " +
            "echo \"CARD|$card\"; " +
            "active=$(pactl list cards 2>/dev/null | awk -v c=\"$card\" '" +
            "  $0 ~ \"Name: \"c {f=1} f&&/Active Profile:/{sub(/.*Active Profile: /,\"\");print;exit}'); " +
            "pactl list cards 2>/dev/null | awk -v c=\"$card\" '" +
            "  $0 ~ \"Name: \"c {f=1} f&&/^[[:space:]]+a2dp-sink/{n=$1; sub(/:$/,\"\",n); " +
            "    d=$0; sub(/^[[:space:]]*a2dp-sink[^:]*: /,\"\",d); sub(/ \\(.*/,\"\",d); " +
            "    print \"PROF|\" n \"|\" d \"|\" (n==a?1:0)}' a=\"$active\""]
        property var accum: []
        property string card: ""
        stdout: SplitParser {
            onRead: (line) => {
                var p = line.split("|")
                if (p[0] === "CARD") pollCodec.card = p[1]
                else if (p[0] === "PROF")
                    pollCodec.accum.push({ id: p[1], desc: p[2] || p[1], active: p[3] === "1" })
            }
        }
        onRunningChanged: {
            if (running) { accum = []; card = "" }
            else { root.codecCard = card; root.codecProfiles = accum; accum = [] }
        }
    }

    // ── Actions ─────────────────────────────────────────────────────────────────
    Process { id: setPower; command: [] }
    Process { id: devAct;   command: [] }
    Process { id: setProf;  command: [] }

    function runSetPower(on) {
        setPower.command = ["bash", "-c", "bluetoothctl power " + (on ? "on" : "off")]
        setPower.running = true
        root.btPowered = on
        if (on) Qt.callLater(root.refresh)
    }

    // verb: connect | disconnect | pair | trust | remove
    function deviceAction(verb, mac) {
        root.busyMac = mac
        devAct.command = ["bash", "-c", "bluetoothctl " + verb + " \"$1\"", "bash", mac]
        devAct.running = true
    }
    Connections {
        target: devAct
        function onRunningChanged() {
            if (!devAct.running) { root.busyMac = ""; Qt.callLater(root.refresh) }
        }
    }

    function setProfile(profId) {
        if (root.codecCard === "") return
        setProf.command = ["pactl", "set-card-profile", root.codecCard, profId]
        setProf.running = true
    }
    Connections {
        target: setProf
        function onRunningChanged() { if (!setProf.running) pollCodec.running = true }
    }

    // ── UI ──────────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // Header + power toggle
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Bluetooth"
                color: Theme.fg
                font.pixelSize: 14
                font.bold: true
                font.family: Theme.font
                Layout.fillWidth: true
            }
            Rectangle {
                width: 44; height: 24; radius: 12
                color: root.btPowered ? Theme.accentBg : Theme.bgAlt
                Behavior on color { ColorAnimation { duration: 100 } }
                Rectangle {
                    width: 18; height: 18; radius: 9
                    x: root.btPowered ? parent.width - width - 3 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.btPowered ? Theme.accent : Theme.gray
                    Behavior on x { NumberAnimation { duration: 100 } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.runSetPower(!root.btPowered)
                }
            }
        }

        Text {
            visible: !root.btPowered
            text: "Bluetooth is off"
            color: Theme.grayDim
            font.pixelSize: 11
            font.family: Theme.font
        }

        // Device list
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: root.btPowered
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: root.width
                spacing: 4

                Text {
                    visible: root.devices.length === 0
                    text: "Scanning…"
                    color: Theme.grayDim
                    font.pixelSize: 11
                    font.family: Theme.font
                }

                Repeater {
                    model: root.devices

                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 8
                        color: modelData.connected ? Theme.accentBg : Theme.bgAlt

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                            spacing: 8

                            Text {
                                text: modelData.connected ? "" : (modelData.paired ? "" : "")
                                color: modelData.connected ? Theme.accent : Theme.gray
                                font.pixelSize: 14
                                font.family: Theme.font
                            }
                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.name
                                    color: modelData.connected ? Theme.fg : Theme.fgDim
                                    font.pixelSize: 12
                                    font.family: Theme.font
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    visible: modelData.battery !== ""
                                    text: "󰂄 " + modelData.battery + "%"
                                    color: Theme.gray
                                    font.pixelSize: 9
                                    font.family: Theme.font
                                }
                            }

                            // Busy spinner / action buttons
                            Text {
                                visible: root.busyMac === modelData.mac
                                text: "…"
                                color: Theme.yellow
                                font.pixelSize: 14
                                font.family: Theme.font
                            }
                            // Pair (only if unpaired)
                            BtActionButton {
                                visible: root.busyMac === "" && !modelData.paired
                                glyph: ""
                                onTriggered: root.deviceAction("pair", modelData.mac)
                            }
                            // Connect / disconnect
                            BtActionButton {
                                visible: root.busyMac === ""
                                glyph: modelData.connected ? "" : ""
                                accent: !modelData.connected
                                onTriggered: root.deviceAction(modelData.connected ? "disconnect" : "connect", modelData.mac)
                            }
                            // Remove
                            BtActionButton {
                                visible: root.busyMac === "" && modelData.paired
                                glyph: ""
                                danger: true
                                onTriggered: root.deviceAction("remove", modelData.mac)
                            }
                        }
                    }
                }

                // Codec / profile selector for the active bluez card
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 4
                    visible: root.codecProfiles.length > 0

                    Text {
                        text: "Codec / profile"
                        color: Theme.gray
                        font.pixelSize: 11
                        font.bold: true
                        font.family: Theme.font
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: root.codecProfiles
                            delegate: Rectangle {
                                required property var modelData
                                width: profTxt.implicitWidth + 18
                                height: 26
                                radius: 6
                                color: modelData.active ? Theme.accentBg
                                     : (profArea.containsMouse ? Theme.bgSoft : Theme.bgAlt)
                                Behavior on color { ColorAnimation { duration: 80 } }
                                Text {
                                    id: profTxt
                                    anchors.centerIn: parent
                                    text: modelData.desc
                                    color: modelData.active ? Theme.fg : Theme.gray
                                    font.pixelSize: 10
                                    font.family: Theme.font
                                }
                                MouseArea {
                                    id: profArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setProfile(modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Small round action button ───────────────────────────────────────────────
    component BtActionButton: Rectangle {
        property string glyph: ""
        property bool accent: false
        property bool danger: false
        signal triggered()

        width: 28; height: 28; radius: 7
        color: btnArea.containsMouse
            ? (danger ? Theme.redDark : Theme.borderStrong)
            : "transparent"
        Behavior on color { ColorAnimation { duration: 80 } }

        Text {
            anchors.centerIn: parent
            text: parent.glyph
            color: parent.danger ? Theme.red : (parent.accent ? Theme.accent : Theme.gray)
            font.pixelSize: 12
            font.family: Theme.font
        }
        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.triggered()
        }
    }
}
