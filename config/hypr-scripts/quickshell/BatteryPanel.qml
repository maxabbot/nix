// BatteryPanel.qml — Battery page (embedded in Settings.qml — no window chrome).
// Charge %, state, health and time-remaining via upower, plus the Framework
// charge-limit threshold (charge_control_end_threshold). Writing the threshold
// needs the sysfs file to be writable — see the udev rule in modules/nixos/base.nix.
// The whole page hides its battery detail on machines with no battery (desktop).
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool   present:        false
    property int    percent:        0
    property string state:          ""    // charging | discharging | fully-charged
    property real   health:         0     // capacity %
    property string timeRemaining:  ""
    property int    threshold:      100
    property bool   thresholdAvail: false
    property string thresholdFile:  ""
    property string status:         ""

    onVisibleChanged: if (visible) { pollBat.running = true; pollThresh.running = true }

    // upower battery details, one "KEY|value" line each.
    Process {
        id: pollBat
        command: ["bash", "-c",
            "b=$(upower -e 2>/dev/null | grep -m1 'battery_BAT'); " +
            "[ -z \"$b\" ] && b=$(upower -e 2>/dev/null | grep -m1 'battery'); " +
            "[ -z \"$b\" ] && { echo 'NONE|'; exit 0; }; " +
            "i=$(upower -i \"$b\"); " +
            "echo \"P|$(echo \"$i\" | grep -oP 'percentage:\\s*\\K[0-9]+')\"; " +
            "echo \"S|$(echo \"$i\" | grep -oP 'state:\\s*\\K\\S+')\"; " +
            "echo \"C|$(echo \"$i\" | grep -oP 'capacity:\\s*\\K[0-9.]+')\"; " +
            "echo \"T|$(echo \"$i\" | grep -oP 'time to (empty|full):\\s*\\K.*')\""]
        stdout: SplitParser {
            onRead: (line) => {
                var p = line.split("|")
                switch (p[0]) {
                    case "NONE": root.present = false; break
                    case "P": root.present = true; root.percent = parseInt(p[1]) || 0; break
                    case "S": root.state = (p[1] || "").trim(); break
                    case "C": root.health = parseFloat(p[1]) || 0; break
                    case "T": root.timeRemaining = (p[1] || "").trim(); break
                }
            }
        }
    }

    Process {
        id: pollThresh
        command: ["bash", "-c",
            "f=$(ls /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null | head -n1); " +
            "[ -z \"$f\" ] && { echo 'NONE|'; exit 0; }; echo \"$f|$(cat \"$f\")\""]
        stdout: SplitParser {
            onRead: (line) => {
                var p = line.split("|")
                if (p[0] === "NONE") { root.thresholdAvail = false; return }
                root.thresholdAvail = true
                root.thresholdFile = p[0]
                root.threshold = parseInt(p[1]) || 100
            }
        }
    }

    Process {
        id: setThresh
        command: []
        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim() === "DENIED")
                    root.status = "Permission denied — sysfs threshold not writable"
            }
        }
    }
    function applyThreshold(v) {
        if (root.thresholdFile === "") return
        root.status = ""
        setThresh.command = ["bash", "-c",
            "echo \"$1\" > \"$2\" 2>/dev/null && echo OK || echo DENIED",
            "bash", String(v), root.thresholdFile]
        setThresh.running = true
        root.threshold = v
    }
    Connections {
        target: setThresh
        function onRunningChanged() { if (!setThresh.running) pollThresh.running = true }
    }

    readonly property string stateIcon: {
        if (state === "charging") return "󰂄"
        if (state === "fully-charged") return "󰁹"
        if (percent <= 10) return "󰂎"
        if (percent <= 30) return "󰁻"
        if (percent <= 60) return "󰁾"
        return "󰁹"
    }
    readonly property color stateColor:
        state === "charging" ? Theme.green
        : percent <= 15 ? Theme.red
        : percent <= 30 ? Theme.yellow : Theme.accent

    Column {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        spacing: 14

        Text {
            text: "Battery"
            color: Theme.fg
            font.pixelSize: 14
            font.bold: true
            font.family: Theme.font
        }

        Text {
            visible: !root.present
            text: "No battery detected"
            color: Theme.grayDim
            font.pixelSize: 12
            font.family: Theme.font
        }

        // ── Charge summary ─────────────────────────────────────────────────────
        RowLayout {
            visible: root.present
            width: parent.width
            spacing: 12

            Text {
                text: root.stateIcon
                color: root.stateColor
                font.pixelSize: 34
                font.family: Theme.font
            }
            ColumnLayout {
                spacing: 2
                Text {
                    text: root.percent + "%"
                    color: Theme.fgBright
                    font.pixelSize: 22
                    font.bold: true
                    font.family: Theme.font
                }
                Text {
                    text: {
                        var s = root.state === "charging" ? "Charging"
                              : root.state === "discharging" ? "Discharging"
                              : root.state === "fully-charged" ? "Full" : root.state
                        if (root.timeRemaining !== "" && root.state !== "fully-charged")
                            s += "  ·  " + root.timeRemaining + " remaining"
                        return s
                    }
                    color: Theme.gray
                    font.pixelSize: 11
                    font.family: Theme.font
                }
            }
        }

        // ── Charge bar ───────────────────────────────────────────────────────────
        Rectangle {
            visible: root.present
            width: parent.width
            height: 8
            radius: 4
            color: Theme.bgAlt
            Rectangle {
                width: parent.width * (root.percent / 100)
                height: parent.height
                radius: 4
                color: root.stateColor
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }

        // ── Health ─────────────────────────────────────────────────────────────
        RowLayout {
            visible: root.present && root.health > 0
            width: parent.width
            Text {
                text: "Health"
                color: Theme.gray
                font.pixelSize: 12
                font.family: Theme.font
                Layout.fillWidth: true
            }
            Text {
                text: Math.round(root.health) + "%"
                color: root.health >= 80 ? Theme.green : root.health >= 60 ? Theme.yellow : Theme.red
                font.pixelSize: 12
                font.family: Theme.font
            }
        }

        // ── Charge limit (Framework) ─────────────────────────────────────────────
        Column {
            visible: root.thresholdAvail
            width: parent.width
            spacing: 6

            Text {
                text: "Charge limit"
                color: Theme.gray
                font.pixelSize: 11
                font.bold: true
                font.family: Theme.font
            }
            Row {
                spacing: 6
                Repeater {
                    model: [60, 80, 90, 100]
                    delegate: Rectangle {
                        required property int modelData
                        width: 56; height: 30; radius: 7
                        color: root.threshold === modelData ? Theme.accentBg
                             : (limArea.containsMouse ? Theme.border : Theme.bgAlt)
                        Behavior on color { ColorAnimation { duration: 80 } }
                        Text {
                            anchors.centerIn: parent
                            text: modelData + "%"
                            color: root.threshold === modelData ? Theme.accent : Theme.fg
                            font.pixelSize: 11
                            font.family: Theme.font
                        }
                        MouseArea {
                            id: limArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.applyThreshold(modelData)
                        }
                    }
                }
            }
            Text {
                visible: root.status !== ""
                text: root.status
                color: Theme.red
                font.pixelSize: 10
                font.family: Theme.font
            }
        }
    }
}
